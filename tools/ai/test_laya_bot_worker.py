"""Worker boundary checks without loading PyTorch or the model."""
import copy
import unittest
from laya_bot_worker import validate_request


class WorkerContractTests(unittest.TestCase):
    def setUp(self):
        self.request = {"schema_version": 1, "request_id": 1, "bot_id": "bot_1",
                        "match_epoch": 2, "life_id": 3,
                        "observation": {"health_fraction": 0.5},
                        "candidates": [{"id": "continue_local", "description": "Keep local tactics."}]}

    def test_game_envelope_and_remaining_deadline(self):
        for ttl in (1, 40, 800, 2000):
            request = {**self.request, "expires_after_ms": ttl}
            self.assertIs(validate_request(request), request)

    def test_nonfinite_nested_observation(self):
        for value in (float("nan"), float("inf"), -float("inf")):
            request = copy.deepcopy(self.request)
            request["observation"]["visible_enemies"] = [{"relative": [0, value, 1]}]
            with self.assertRaises(ValueError): validate_request(request)

    def test_invalid_deadlines(self):
        for value in (None, True, "800", [], {}, 0, -1, 2001, 800.5):
            with self.assertRaises(ValueError):
                validate_request({**self.request, "expires_after_ms": value})

    def test_ambiguous_or_unbounded_candidates(self):
        for candidates in ([], self.request["candidates"] * 2,
                           [{"id": "a b", "description": "Invalid label."}],
                           [{"id": "ok", "description": "a" * 241}],
                           [{"id": str(i), "description": "Choice"} for i in range(7)]):
            with self.assertRaises(ValueError):
                validate_request({**self.request, "candidates": candidates})

    def test_invalid_lifecycle_identity(self):
        for key, value in (("life_id", True), ("match_epoch", -1), ("bot_id", ""), ("request_id", [])):
            with self.assertRaises(ValueError): validate_request({**self.request, key: value})


if __name__ == "__main__": unittest.main()
