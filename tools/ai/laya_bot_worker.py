#!/usr/bin/env python3
"""Loopback-only Laya tactical selector. One resident checkpoint; no physics work.

Run with ~/laya/.venv/bin/python. Model outputs are proposals; Godot owns validity.
"""
from __future__ import annotations
import argparse
import json
import math
import os
from pathlib import Path
import re
import resource
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

MAX_BODY = 32768
MAX_OPTIONS = 6
MAX_LEN = 512
HEAD_LEN = 192
INSTRUCTIONS = "Choose the most useful available KOTH tactic given health, ammunition, objective urgency, visible threats, teammates and route progress."


def require_finite(value):
    if isinstance(value, float) and not math.isfinite(value):
        raise ValueError("Nonfinite observation")
    if isinstance(value, dict):
        for item in value.values(): require_finite(item)
    elif isinstance(value, list):
        for item in value: require_finite(item)


def validate_request(data):
    if not isinstance(data, dict) or data.get("schema_version") != 1:
        raise ValueError("Expected schema_version 1")
    request_id = data.get("request_id")
    if not ((type(request_id) is int and request_id >= 0) or (isinstance(request_id, str) and 1 <= len(request_id) <= 96)):
        raise ValueError("Invalid request_id")
    for key in ("bot_id",):
        if not isinstance(data.get(key), str) or not 1 <= len(data[key]) <= 96:
            raise ValueError("Invalid " + key)
    for key in ("match_epoch", "life_id"):
        if type(data.get(key)) is not int or data[key] < 0:
            raise ValueError("Invalid " + key)
    if not isinstance(data.get("observation"), dict):
        raise ValueError("Expected observation object")
    ttl = data.get("expires_after_ms", 800)
    if type(ttl) is not int or not 1 <= ttl <= 2000:
        raise ValueError("Invalid expires_after_ms")
    if len(json.dumps(data["observation"])) > 6000:
        raise ValueError("Observation too large")
    candidates = data.get("candidates")
    if not isinstance(candidates, list) or not 1 <= len(candidates) <= MAX_OPTIONS:
        raise ValueError("Expected one to six candidates")
    labels = set()
    for option in candidates:
        if not isinstance(option, dict): raise ValueError("Invalid candidate")
        label, description = option.get("id"), option.get("description")
        if not isinstance(label, str) or not re.fullmatch(r"[A-Za-z0-9_-]{1,48}", label):
            raise ValueError("Invalid candidate id")
        if label in labels: raise ValueError("Duplicate candidate id")
        labels.add(label)
        if not isinstance(description, str) or not 1 <= len(description) <= 240:
            raise ValueError("Invalid candidate description")
    require_finite(data)
    return data


class Selector:
    def __init__(self, args):
        import torch
        import laya
        from laya import Router
        self.torch = torch
        torch.set_num_threads(args.cpu_threads)
        torch.set_num_interop_threads(1)
        self.log_path = Path(args.log) if args.log else None
        if self.log_path: self.log_path.parent.mkdir(parents=True, exist_ok=True)
        self.log_lock = threading.Lock()
        self.inference_lock = threading.Lock()
        self.pending = threading.BoundedSemaphore(2)
        self.counters = {"requests": 0, "inferences": 0, "invalid": 0, "busy": 0, "errors": 0}
        self.package_version = laya.__version__
        self.model_id = args.model_path or "convaiinnovations/laya"
        manifest_path = Path(args.manifest).expanduser()
        revision = args.revision
        if not args.model_path and not revision:
            if manifest_path.exists():
                revision = json.loads(manifest_path.read_text())["revision"]
                os.environ.setdefault("HF_HUB_OFFLINE", "1")
            else:
                from huggingface_hub import HfApi
                revision = HfApi().model_info(self.model_id).sha
        self.revision = revision or "local-checkpoint"
        self.router = Router(models={"english": self.model_id}, device=args.device,
                             revision=revision, max_loaded=1, agent_kwargs={"backend": "eager"})
        started = time.perf_counter()
        self.agent = self.router.load("english")
        self.device = str(self.agent.device)
        warm_request = {"schema_version": 1, "request_id": "warmup", "bot_id": "warmup",
                        "match_epoch": 0, "life_id": 0,
                        "observation": {"health": "healthy", "ammo": "full", "objective": "enemy owned"},
                        "candidates": [{"id": "capture", "description": "Advance to capture the hill."},
                                       {"id": "defend", "description": "Hold a friendly-owned hill."}]}
        for _ in range(3): self.select(warm_request, log=False)
        self.preload_ms = (time.perf_counter() - started) * 1000
        manifest = {"laya_version": self.package_version, "model_id": self.model_id,
                    "revision": self.revision, "device": self.device, "torch_version": torch.__version__,
                    "max_len": MAX_LEN, "head_max_len": HEAD_LEN, "preload_ms": self.preload_ms,
                    "cpu_threads": args.cpu_threads}
        manifest_path.parent.mkdir(parents=True, exist_ok=True)
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        self.record({"event": "ready", **manifest, **self.memory()})

    def memory(self):
        peak = resource.getrusage(resource.RUSAGE_SELF).ru_maxrss
        result = {"peak_rss_mib": peak / (1024 * 1024 if sys.platform == "darwin" else 1024)}
        if self.device == "mps":
            result["mps_allocated_mib"] = self.torch.mps.current_allocated_memory() / 1024**2
            result["mps_driver_mib"] = self.torch.mps.driver_allocated_memory() / 1024**2
        return result

    def record(self, item):
        if self.log_path:
            with self.log_lock, self.log_path.open("a") as stream:
                stream.write(json.dumps(item, separators=(",", ":"), allow_nan=False) + "\n")

    def select(self, request, log=True):
        from laya.common import build_sequence
        observation = request["observation"]
        # Metadata/bindings stay outside the model; only bot-perceived state enters.
        state = json.dumps(observation, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        # Canonical IDs make caller list order irrelevant. Opposite slot orders
        # reduce the checkpoint's measured positional preference; no new weights.
        criteria = {option["id"]: option["description"] for option in
                    sorted(request["candidates"], key=lambda option: option["id"])}
        internal_question = {"t": "choice", "ins": INSTRUCTIONS, "crit": criteria}
        _, markers, option_stats, state_stats = build_sequence(
            self.agent.tok, state, internal_question, MAX_LEN, HEAD_LEN,
            return_stats=True, return_truncation_stats=True)
        if state_stats["truncated"] or len(markers) != len(criteria) or option_stats["options_distinct"] != len(criteria) or option_stats["tokens_per_option"] is not None:
            raise ValueError("Token budget would truncate state or candidate definitions")
        started, cpu_started = time.perf_counter(), time.process_time()
        if self.device == "mps": self.torch.mps.synchronize()
        passes = []
        for order in (list(range(len(criteria))), list(reversed(range(len(criteria))))):
            answer = self.router.predict(state, {"next_plan": {"type": "choice", "instructions": INSTRUCTIONS,
                                                              "criteria": criteria, "option_order": order}},
                                         model="english", max_len=MAX_LEN,
                                         head_max_len=HEAD_LEN)["answers"]["next_plan"]
            scores = answer.get("probabilities", {})
            if set(scores) != set(criteria) or any(not isinstance(value, (int, float)) or
                    not math.isfinite(value) or value < 0 for value in scores.values()):
                raise RuntimeError("Model returned invalid candidate probabilities")
            passes.append({"order": order, "choice": answer["choice"], "probabilities": scores})
            self.counters["inferences"] += 1
        if self.device == "mps": self.torch.mps.synchronize()
        elapsed = (time.perf_counter() - started) * 1000
        cpu_ms = (time.process_time() - cpu_started) * 1000
        probabilities = {key: sum(result["probabilities"][key] for result in passes) / len(passes)
                         for key in criteria}
        selection = max(criteria, key=lambda key: probabilities[key])
        response = {key: request[key] for key in ("request_id", "match_epoch", "bot_id", "life_id")}
        response.update({"schema_version": 1, "selected_candidate": selection,
                         "confidence": probabilities[selection],
                         "probabilities": probabilities, "latency_ms": elapsed,
                         "selection_policy": "canonical_reverse_mean_v1", "selection_passes": passes,
                         "model_version": self.package_version, "model_id": self.model_id,
                         "model_revision": self.revision, "device": self.device,
                         "state_tokens": state_stats["state_tokens"], "state_truncated": False,
                         "cpu_ms": cpu_ms})
        if log: self.record({"event": "decision", "wall_time": time.time(), "request": request,
                             "response": response, **self.memory()})
        return response

    def health(self):
        return {"ready": True, "device": self.device, "model_version": self.package_version,
                "model_id": self.model_id, "model_revision": self.revision,
                "counters": dict(self.counters), **self.memory()}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"

    def log_message(self, format, *args): pass

    def send_json(self, status, value):
        body = json.dumps(value, allow_nan=False, separators=(",", ":")).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try: self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError): pass

    def do_GET(self):
        if self.path == "/health": self.send_json(200, self.server.selector.health())
        else: self.send_json(404, {"error": "unknown_endpoint"})

    def do_POST(self):
        selector = self.server.selector
        if self.path != "/decision":
            self.send_json(404, {"error": "unknown_endpoint"}); return
        started = time.perf_counter()
        selector.counters["requests"] += 1
        try:
            count = int(self.headers.get("Content-Length", "0"))
            if not 0 < count <= MAX_BODY: raise ValueError("Body size outside limit")
            self.connection.settimeout(2.0)
            raw = self.rfile.read(count)
            if len(raw) != count: raise ValueError("Incomplete body")
            request = validate_request(json.loads(raw, parse_constant=lambda value: (_ for _ in ()).throw(ValueError("Nonfinite JSON"))))
        except (ValueError, TypeError, RecursionError, TimeoutError) as error:
            selector.counters["invalid"] += 1
            self.send_json(422, {"error": "invalid_request", "detail": str(error)}); return
        if not selector.pending.acquire(blocking=False):
            selector.counters["busy"] += 1
            self.send_json(503, {"error": "busy"}); return
        try:
            with selector.inference_lock:
                age_ms = (time.perf_counter() - started) * 1000
                ttl = request.get("expires_after_ms", 800)
                if age_ms >= ttl:
                    self.send_json(503, {"error": "queue_expired"}); return
                response = selector.select(request)
                response["total_latency_ms"] = (time.perf_counter() - started) * 1000
            self.send_json(200, response)
        except ValueError as error:
            selector.counters["invalid"] += 1
            selector.record({"event": "rejected", "request_id": request["request_id"], "error": str(error)})
            self.send_json(422, {"error": "invalid_request", "detail": str(error)})
        except Exception as error:
            selector.counters["errors"] += 1
            selector.record({"event": "error", "request_id": request["request_id"], "error": str(error)})
            self.send_json(500, {"error": "inference_failed"})
        finally: selector.pending.release()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, default=27878)
    parser.add_argument("--device", choices=("mps", "cpu"), default="mps")
    parser.add_argument("--cpu-threads", type=int, default=2)
    parser.add_argument("--model-path", default="")
    parser.add_argument("--revision", default="")
    parser.add_argument("--manifest", default=str(Path.home() / "laya/model-manifest.json"))
    parser.add_argument("--log", default="")
    args = parser.parse_args()
    selector = Selector(args)
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    server.selector = selector
    print(json.dumps({"event": "listening", "port": args.port, **selector.health()}), flush=True)
    try: server.serve_forever(poll_interval=0.25)
    except KeyboardInterrupt: pass
    finally: server.server_close()


if __name__ == "__main__": main()
