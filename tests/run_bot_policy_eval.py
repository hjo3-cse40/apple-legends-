"""Plan/run paired real-time bot-policy arms and summarize auditable match KPIs.

The local/shadow/enabled arms use the SAME current bot/controller code. The old
0.4.3 source is a separate historical check, never the enabled arm's control.
Actual model requests must run at wall-time cadence; accelerated replay is not
live inference evidence. Long outputs live in ignored work/, not source control.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import pathlib
import random
import statistics
import subprocess
import time
import urllib.request

REPO = pathlib.Path(__file__).resolve().parent.parent
GODOT = pathlib.Path('/Applications/Godot.app/Contents/MacOS/Godot')
ARMS = {'local': 0, 'shadow': 1, 'enabled': 2}
PRIMARY = ('grounded_reach_fraction', 'grounded_reach_by_30s', 'restricted_hill_time_30s',
           'objective_actor_seconds', 'maximum_waypoint_dwell_seconds')


def percentile(values, fraction):
    if not values:
        return None
    values = sorted(values)
    index = (len(values) - 1) * fraction
    low = int(index)
    high = min(low + 1, len(values) - 1)
    return values[low] * (1 - (index - low)) + values[high] * (index - low)


def distribution(values):
    return {'n': len(values), 'mean': statistics.fmean(values) if values else None,
            'median': percentile(values, .5), 'p95': percentile(values, .95),
            'p99': percentile(values, .99), 'max': max(values) if values else None}


def make_plan(seeds, seconds, include_diagnostics=True):
    runs = []
    # Rotate arm order to limit warm-up/thermal/order confounding. One seed's
    # three arms are a block; all six bots have matched per-bot RNG offsets.
    order = list(ARMS)
    for block, seed in enumerate(seeds):
        for arm in order[block % 3:] + order[:block % 3]:
            runs.append({'id': f'normal-{seed}-{arm}', 'arm': arm, 'seed': seed,
                         'seconds': seconds, 'difficulty': 1, 'teams': [], 'native': False,
                         'comparison': 'paired-primary'})
    if include_diagnostics:
        for team in [1, 2]:
            runs.append({'id': f'mixed-team-{team}', 'arm': 'enabled', 'seed': seeds[0],
                         'seconds': 180, 'difficulty': 1, 'teams': [team], 'native': False,
                         'comparison': 'team-asymmetry-diagnostic'})
        runs.append({'id': 'expert-enabled', 'arm': 'enabled', 'seed': seeds[-1],
                     'seconds': 180, 'difficulty': 2, 'teams': [], 'native': False,
                     'comparison': 'expert-diagnostic'})
        for arm in ARMS:
            runs.append({'id': f'native-{arm}', 'arm': arm, 'seed': seeds[0], 'seconds': 60,
                         'difficulty': 1, 'teams': [], 'native': True,
                         'comparison': 'frame-pacing-diagnostic'})
    return {'schema_version': 1, 'primary_kpis': list(PRIMARY), 'seeds': seeds,
            'seconds_cap_per_primary': seconds,
            'estimated_minimum_wall_minutes': sum(run['seconds'] for run in runs) / 60,
            'predeclared_interpretation': [
                'Compare enabled to same-code local by paired seed, never to historical0.4.3.',
                'Report all arms and all primary KPIs; kills/captures alone are not proof of improvement.',
                'Grounded reach includes completed lives; unfinished lives are separately censored.',
                'Reach-by30s and restricted time exclude surviving lives censored before30s.',
                'Waypoint dwell records movement without route progress; low-speed stalls alone miss orbits.',
                'Three seeds give wide uncertainty and do not establish other maps, human skill or Air performance.',
                'Actual model decisions are distinct from synthetic faults and offline scenario labels.',
                'Native wall-frame pacing covers combined CPU/GPU interference; direct GPUtime is unmeasured.',
            ], 'runs': runs}


def make_followup_plan(seeds, seconds):
    plan = make_plan(seeds, seconds, include_diagnostics=False)
    plan['runs'] = [run for run in plan['runs'] if run['arm'] != 'shadow' or run['seed']==seeds[0]]
    for run in plan['runs']: run['motion_trace']=True
    for run in make_plan(seeds, seconds)['runs']:
        if run['native']:
            run['screenshots'] = False
            plan['runs'].append(run)
    plan['reason'] = 'Same frozen local controller with canonical-forward/reverse averaged worker selection; preserve original stock-order9gameblock separately. No weight/corpus-label tuning.'
    plan['required_primary_arms'] = ['local','enabled']
    plan['shadow_diagnostic_seeds'] = [seeds[0]]
    plan['estimated_minimum_wall_minutes'] = sum(run['seconds'] for run in plan['runs'])/60
    plan['predeclared_interpretation'].append('Followup: three Local/Enabled seed pairs and one complete Local/Shadow/Enabled block; native capture disabled to avoid PNG stalls.')
    return plan


def bot_kpis(actor):
    lives = actor.get('lives', [])
    # Unfinished alive life is a censored observation, not a death/failure.
    completed = [life for life in lives if life.get('end_reason') in ('death', 'forced_respawn')]
    terminal_reached = [life for life in lives if life.get('first_grounded_hill_time', -1) >= 0]
    completed_reached = [life for life in completed if life.get('first_grounded_hill_time', -1) >= 0]
    eligible_30, reach_30, restricted_30 = 0, 0, []
    event_times = []
    for life in lives:
        start = life['spawn_time']
        duration = life['end_time'] - start
        first = life.get('first_grounded_hill_time', -1)
        event_time = first - start if first >= 0 else None
        if event_time is not None:
            event_times.append(event_time)
        if life.get('end_reason') in ('death', 'forced_respawn') or duration >= 30 or event_time is not None:
            eligible_30 += 1
            reached_30 = event_time is not None and event_time <= 30
            reach_30 += int(reached_30)
            restricted_30.append(min(event_time, 30) if event_time is not None else 30)
    return {'team': actor['team'], 'role': actor['role'], 'lives': len(lives),
            'completed_lives': len(completed), 'completed_grounded_reached': len(completed_reached),
            'censored_lives': len(lives) - len(completed), 'all_grounded_reached': len(terminal_reached),
            'eligible_30': eligible_30, 'reached_30': reach_30, 'restricted_30': restricted_30,
            'grounded_event_times': event_times}


def worker_pass_metadata(round_data):
    paths = sorted((REPO/'work').glob('laya-worker*.jsonl'))
    start, end = round_data.get('wall_start_unix'), round_data.get('wall_end_unix')
    if start is None or end is None or not paths:
        return {'available': False, 'reason': 'Per-round UNIX markers or worker log unavailable.'}
    identities = {(event.get('request_id'), event.get('match_epoch'), event.get('bot_id'),
                   event.get('life_id')) for event in round_data.get('policy_events', [])}
    choices = []
    used_logs = set()
    for path in paths:
        with path.open() as stream:
            for line in stream:
                try:
                    record = json.loads(line)
                except json.JSONDecodeError:
                    continue
                if record.get('event') != 'decision' or not start <= record.get('wall_time', 0) <= end:
                    continue
                request = record['request']
                identity = tuple(request.get(key) for key in ('request_id', 'match_epoch', 'bot_id', 'life_id'))
                if identity not in identities:
                    continue
                response = record['response']
                passes = response.get('selection_passes', [])
                if not passes:
                    continue
                used_logs.add(str(path.relative_to(REPO)))
                choices.append({'request_id': request['request_id'], 'selected_candidate': response['selected_candidate'],
                                'raw_pass_choices': [item['choice'] for item in passes],
                                'disagree': len({item['choice'] for item in passes}) > 1,
                                'selection_policy': response.get('selection_policy')})
    return {'available': True, 'matched_completed_events': len(choices),
            'raw_pass_disagreements': sum(item['disagree'] for item in choices),
            'raw_pass_disagreement_fraction': sum(item['disagree'] for item in choices)/len(choices) if choices else None,
            'logs_used': sorted(used_logs), 'choices': choices,
            'scope': 'Worker responses joined to client decision events by identity plus UNIX round interval; canceled/unobserved responses excluded.'}


def match_kpis(round_data):
    actors = round_data['actors']
    life = [bot_kpis(actor) for actor in actors.values()]
    n_completed = sum(item['completed_lives'] for item in life)
    n_reached = sum(item['completed_grounded_reached'] for item in life)
    n_eligible_30 = sum(item['eligible_30'] for item in life)
    reach_30 = sum(item['reached_30'] for item in life)
    restricted = [number for item in life for number in item['restricted_30']]
    metrics = round_data.get('policy_metrics', {})
    events = round_data.get('policy_events', [])
    valid_events = [event for event in events if event.get('outcome') in ('shadow', 'applied')]
    valid_latencies = [event['latency_ms'] for event in valid_events if 'latency_ms' in event]
    if not valid_latencies:
        valid_latencies = metrics.get('latency_ms', [])
    outcomes = {}
    selected = {}
    for event in events:
        outcomes[event['outcome']] = outcomes.get(event['outcome'], 0) + 1
        if 'selected_candidate' in event:
            selected[event['selected_candidate']] = selected.get(event['selected_candidate'], 0) + 1
    contextual_choices = {}
    for event in events:
        if 'selected_candidate' not in event:
            continue
        obs = event.get('observation', {})
        tags = {'role': obs.get('role', 'unknown'),
                'health_band': 'low' if obs.get('health_fraction',1) <= .4 else 'healthy',
                'ammo_band': 'low' if obs.get('ammo',12) <= max(2,obs.get('magazine_size',12)/4) else 'loaded',
                'urgency': obs.get('objective_urgency','unknown')}
        for dimension, tag in tags.items():
            bucket = contextual_choices.setdefault(dimension,{}).setdefault(str(tag),{})
            action = event['selected_candidate']
            bucket[action] = bucket.get(action,0)+1
    return {'seed': round_data['seed'], 'difficulty': round_data.get('difficulty'),
            'duration_seconds': round_data['duration'], 'wall_seconds': round_data.get('wall_seconds'),
            'winner': round_data['winner'], 'match_complete': round_data['match_complete'],
            'remaining_clocks': round_data['remaining_clocks'], 'captures': len(round_data['captures']),
            'contested_seconds': round_data['contested_seconds'],
            'grounded_reach_fraction': n_reached / n_completed if n_completed else None,
            'completed_lives': n_completed, 'completed_reached': n_reached,
            'censored_lives': sum(item['censored_lives'] for item in life),
            'grounded_reach_by_30s': reach_30 / n_eligible_30 if n_eligible_30 else None,
            'restricted_hill_time_30s': statistics.fmean(restricted) if restricted else None,
            'objective_actor_seconds': sum(actor.get('hill_grounded_seconds', 0) for actor in actors.values()),
            'maximum_waypoint_dwell_seconds': max(actor['maximum_waypoint_dwell'] for actor in actors.values()),
            'maximum_low_displacement_stall_seconds': max(actor['maximum_goal_stall'] for actor in actors.values()),
            'shots': sum(actor['shots'] for actor in actors.values()),
            'deaths': sum(actor['deaths'] for actor in actors.values()),
            'damage_taken': sum(actor['damage_taken'] for actor in actors.values()),
            'reloads': sum(actor['reloads'] for actor in actors.values()),
            'model_metrics': metrics, 'model_outcomes': outcomes, 'selected_actions': selected,
            'selected_nonlocal': sum(n for action,n in selected.items() if action!='continue_local'),
            'selected_delegations': selected.get('continue_local',0),
            'actual_snapshot_choice_context':contextual_choices,
            'valid_model_latency_ms': distribution(valid_latencies),
            'frame_metrics': round_data.get('frame_metrics', {}), 'per_bot_lives': life,
            'duration_normalized_per_60s': {name: sum(actor.get(field,0) for actor in actors.values())*60/round_data['duration'] for name,field in [('objective_actor_seconds','hill_grounded_seconds'),('shots','shots'),('deaths','deaths'),('damage_taken','damage_taken'),('jumps','jumps'),('travel_distance','travel_distance')]},
            'movement': {'sprint_seconds':sum(actor['sprint_seconds'] for actor in actors.values()),
                         'jumps':sum(actor['jumps'] for actor in actors.values()),
                         'travel_distance':sum(actor['travel_distance'] for actor in actors.values()),
                         'alive_seconds':sum(actor['alive_seconds'] for actor in actors.values()),
                         'mean_distance_per_alive_second':sum(actor['travel_distance'] for actor in actors.values())/max(.001,sum(actor['alive_seconds'] for actor in actors.values())),
                         'per_bot_route_progress':{key: {'maximum_route_index':actor['maximum_route_index'],'route_variants':actor['route_variants']} for key,actor in actors.items()}},
            'latency_all_successful_http_ms':distribution(metrics.get('latency_ms',[])),
            'worker_pass_metadata':worker_pass_metadata(round_data),
            'per_team': {str(team): {'objective_actor_seconds':sum(actor['hill_grounded_seconds'] for actor in actors.values() if actor['team']==team),
                       'deaths':sum(actor['deaths'] for actor in actors.values() if actor['team']==team),
                       'shots':sum(actor['shots'] for actor in actors.values() if actor['team']==team),
                       'damage_taken':sum(actor['damage_taken'] for actor in actors.values() if actor['team']==team),
                       'completed_lives':sum(bot_kpis(actor)['completed_lives'] for actor in actors.values() if actor['team']==team),
                       'completed_reached':sum(bot_kpis(actor)['completed_grounded_reached'] for actor in actors.values() if actor['team']==team)} for team in [1,2]}}


def paired_summary(rows):
    by_seed = {}
    for row in rows:
        if row.get('comparison') == 'paired-primary':
            by_seed.setdefault(row['seed'], {})[row['arm']] = row
    pairs = [arms for arms in by_seed.values() if all(arm in arms for arm in ('local','enabled'))]
    three_arm_pairs = [arms for arms in by_seed.values() if all(arm in arms for arm in ARMS)]
    summary = {'complete_seed_blocks': len(pairs), 'complete_three_arm_seed_blocks':len(three_arm_pairs), 'required_primary_arms':['local','enabled'], 'primary': {}}
    rng = random.Random(48019)
    for kpi in PRIMARY:
        deltas = [pair['enabled'][kpi] - pair['local'][kpi] for pair in pairs
                  if pair['enabled'][kpi] is not None and pair['local'][kpi] is not None]
        samples = []
        if deltas:
            samples = [statistics.fmean(rng.choices(deltas, k=len(deltas))) for _ in range(5000)]
        summary['primary'][kpi] = {'paired_deltas_enabled_minus_local': deltas,
                                   'mean_delta': statistics.fmean(deltas) if deltas else None,
                                   'descriptive_bootstrap_95_percent_interval': [percentile(samples, .025), percentile(samples, .975)],
                                   'uncertainty_note': 'Small fixed-seed sample; interval is descriptive, not a human-skill or all-map inference.'}
    return summary


def summarize(directory):
    directory = pathlib.Path(directory)
    manifest = json.loads((directory / 'plan.json').read_text())
    rows = []
    missing = []
    for run in manifest['runs']:
        path = directory / (run['id'] + '.json')
        if not path.exists():
            missing.append(run['id'])
            continue
        data = json.loads(path.read_text())
        for result in data['rounds']:
            row = match_kpis(result)
            row.update({key: run[key] for key in ('id', 'arm', 'seed', 'difficulty', 'teams', 'native', 'comparison')})
            row['bot_source_sha256'] = data['bot_source_sha256']
            rows.append(row)
    output = {'schema_version': 1, 'plan': manifest, 'missing_runs': missing, 'matches': rows,
              'paired_comparison': paired_summary(rows)}
    (directory / 'summary.json').write_text(json.dumps(output, indent=2))
    print(json.dumps({'matches': len(rows), 'missing': missing, 'paired': output['paired_comparison']}, indent=2))
    return output


def health():
    with urllib.request.urlopen('http://127.0.0.1:27878/health', timeout=5) as response:
        return json.load(response)


def run_suite(args):
    directory = pathlib.Path(args.directory).resolve()
    directory.mkdir(parents=True, exist_ok=True)
    plan_path = directory / 'plan.json'
    if not plan_path.exists():
        plan_path.write_text(json.dumps(make_followup_plan(args.seeds,args.seconds) if args.followup else make_plan(args.seeds, args.seconds, not args.primary_only), indent=2))
    plan = json.loads(plan_path.read_text())
    source_files = ['scenes/bots/duel_bot.gd', 'scenes/bots/tactical_decision_client.gd',
                    'scenes/match/team_match_manager.gd', 'tools/ai/laya_bot_worker.py',
                    'tests/bot_live_match_eval.gd']
    fingerprints = {name: hashlib.sha256((REPO/name).read_bytes()).hexdigest() for name in source_files}
    freeze_path = directory/'source-freeze.json'
    if freeze_path.exists():
        if json.loads(freeze_path.read_text()) != fingerprints:
            raise RuntimeError('Source changed since this evaluation block was frozen; use a separate block directory.')
    else:
        freeze_path.write_text(json.dumps(fingerprints, indent=2)+'\n')
    selected = set(args.only or [])
    for run in plan['runs']:
        if any(hashlib.sha256((REPO/name).read_bytes()).hexdigest() != digest for name,digest in fingerprints.items()):
            raise RuntimeError('Source changed during evaluation; stop and start a new block.')
        if selected and run['id'] not in selected:
            continue
        output = directory / (run['id'] + '.json')
        if output.exists() and args.resume:
            print('SKIP completed', run['id'], flush=True)
            continue
        if run['arm'] != 'local':
            status = health()
            if not status.get('ready'):
                raise RuntimeError('Actual model worker must be ready before model arms: ' + repr(status))
            (directory / (run['id'] + '.worker-health.json')).write_text(json.dumps(status, indent=2))
        command = [str(GODOT), '--path', str(REPO)]
        command += ['--resolution', '1280x720'] if run['native'] else ['--headless']
        command += ['--script', 'res://tests/bot_live_match_eval.gd', '--', 'realtime',
                    'runs=1', f"seconds={run['seconds']}", f"level={run['difficulty']}",
                    f"seed={run['seed']}", f"policy={ARMS[run['arm']]}",
                    f"tag={run['id']}", f'output={output}']
        if run.get('motion_trace'):
            command.append(f"motion_trace={directory / (run['id'] + '.motion-trace.json')}")
        if run['teams']:
            command.append('teams=' + ','.join(str(team) for team in run['teams']))
        if run['native'] and run.get('screenshots',True):
            command.append(f"screenshots={directory / run['id']}")
        print('RUN', run['id'], 'cap_seconds', run['seconds'], flush=True)
        started = time.monotonic()
        with (directory / (run['id'] + '.log')).open('w') as log:
            process = subprocess.Popen(command, cwd=REPO, stdout=log, stderr=subprocess.STDOUT)
            try:
                code = process.wait(timeout=run['seconds'] + 150)
            except (subprocess.TimeoutExpired, KeyboardInterrupt):
                process.kill()
                process.wait()
                raise RuntimeError('Evaluation timed out: ' + run['id'])
        text = (directory / (run['id'] + '.log')).read_text()
        if code or 'SCRIPT ERROR' in text or 'BOT_LIVE_EVAL_PASS' not in text or not output.exists():
            raise RuntimeError('Evaluation failed: ' + run['id'] + '\n' + text[-3000:])
        print('DONE', run['id'], 'wall_seconds', round(time.monotonic() - started, 1), flush=True)
        summarize(directory)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest='mode', required=True)
    for name in ('plan', 'run'):
        command = sub.add_parser(name)
        command.add_argument('--directory', default=str(REPO / 'work/policy-eval'))
        command.add_argument('--seeds', nargs='+', type=int, default=[173, 1073, 2073])
        command.add_argument('--seconds', type=int, default=300)
        command.add_argument('--primary-only', action='store_true')
        command.add_argument('--followup', action='store_true',help='Three Local/Enabled pairs, one Shadow block, native arms without screenshots.')
        if name == 'run':
            command.add_argument('--resume', action='store_true')
            command.add_argument('--only', nargs='+')
    command = sub.add_parser('summarize')
    command.add_argument('directory')
    args = parser.parse_args()
    if args.mode == 'run':
        run_suite(args)
    elif args.mode == 'plan':
        directory = pathlib.Path(args.directory)
        directory.mkdir(parents=True, exist_ok=True)
        plan = make_followup_plan(args.seeds,args.seconds) if args.followup else make_plan(args.seeds, args.seconds, not args.primary_only)
        (directory / 'plan.json').write_text(json.dumps(plan, indent=2))
        print(json.dumps(plan, indent=2))
    else:
        summarize(args.directory)


if __name__ == '__main__':
    main()
