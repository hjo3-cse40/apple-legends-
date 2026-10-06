"""Predeclared synthetic tactical plausibility corpus, separate from live-game improvement.

Development families may guide formatting/training. Heldout families stay sealed
until the formatter/model is frozen. Labels are permissive domain rubrics, not
human-skill labels. continue_local is accepted where its local fallback is safe;
local baseline delegates in every scenario. These are synthetic offered options,
not a faithful replay of production geometry/gateway/cooldown eligibility. The
route-stall family is a counterfactual: live local recovery already activates
after2.5s, and its rubric preference for commitment is not proof local is wrong.
"""
from __future__ import annotations
import argparse
import copy
import hashlib
import json
import pathlib
import random
import statistics
import urllib.error
import urllib.request

REPO = pathlib.Path(__file__).resolve().parent.parent
DESCRIPTIONS = {
 'continue_local': "Keep the local controller's current tactical choice, aim, fire and movement.",
 'continue_objective': 'Commit to the current safe route and capture or defend the hill; keep firing at visible enemies.',
 'reload_cover': 'Reload the low magazine while moving into this nearby verified cover from the observed enemy.',
 'retreat_safe': 'Low health: briefly retreat toward this collision-verified nearby escape; then return to local objective decisions.',
 'engage_left': 'Fight the visible enemy with a sustained left lateral posture; respect waypoint and capture urgency.',
 'engage_right': 'Fight the visible enemy with a sustained right lateral posture; respect waypoint and capture urgency.',
 'entry_side': 'At this verified ground gateway, commit to the side authored hill entry.',
 'entry_direct': 'At this verified ground gateway, commit to the direct authored hill entry.',
}


def corpus():
    cases = []
    # Development and heldout differ in tactical family, not just a random seed.
    families = [
      ('development', 'empty_magazine_cover', {'ammo': 0, 'behavior': 'reload'},
       ['continue_local','continue_objective','reload_cover'], ['continue_local','reload_cover']),
      ('development', 'healthy_neutral_hill', {'health_fraction': 1.0, 'ammo': 12, 'visible_enemies': [], 'role': 'anchor'},
       ['continue_local','continue_objective','entry_side'], ['continue_local','continue_objective','entry_side']),
      ('development', 'healthy_owned_hill_fight', {'health_fraction': .9,'ammo': 10,'objective_distance': 2.,'objective_owned_by_team': True},
       ['continue_local','continue_objective','engage_left','engage_right'], ['continue_local','continue_objective','engage_left','engage_right']),
      ('heldout', 'critical_health_escape', {'health_fraction': .15,'ammo': 8,'behavior': 'retreat'},
       ['continue_local','continue_objective','retreat_safe'], ['continue_local','retreat_safe']),
      ('heldout', 'low_magazine_enemy_contest', {'health_fraction': .75,'ammo': 2,'objective_contested': True,'objective_distance': 3.},
       ['continue_local','continue_objective','reload_cover'], ['continue_local','reload_cover']),
      ('heldout', 'route_stall_no_enemy', {'ammo': 12,'visible_enemies': [],'seconds_without_goal_progress': 6.,'waypoint_distance': 8.},
       ['continue_local','continue_objective','entry_direct'], ['continue_objective','entry_direct']),
      ('heldout', 'support_transit_fight', {'health_fraction': .9,'ammo': 10,'role': 'support','objective_owned_by_team': True},
       ['continue_local','continue_objective','engage_left','engage_right'], ['continue_local','continue_objective','engage_left','engage_right']),
    ]
    for split, family, changes, options, acceptable in families:
      for variant in range(3):
        rng = random.Random(18091 + variant)
        obs = dict(health_fraction=.8,ammo=8,magazine_size=12,reloading=False,role='pressure',behavior='advance',
           visible_enemies=[{'distance': 14. + variant,'relative': [4.,0.,12.]}],visible_allies=variant,
           objective_enabled=True,objective_owned_by_team=False,objective_contested=False,
           objective_distance=22.+variant,route_entry='side',waypoint_index=4,waypoint_distance=10.+variant,
           seconds_without_goal_progress=0.,own_clock_seconds=110.,enemy_clock_seconds=90.,objective_urgency='normal')
        obs.update(changes)
        # Same state in three candidate orderings; no label derives from position.
        ordered = list(options)
        if variant: rng.shuffle(ordered)
        request = dict(schema_version=1,request_id=f'scenario-{family}-{variant}',match_epoch=100,bot_id='scenario',life_id=1,
          expires_after_ms=2000,local_candidate='continue_local',observation=obs,
          candidates=[{'id': key,'description':DESCRIPTIONS[key]} for key in ordered])
        cases.append(dict(split=split,family=family,variant=variant,acceptable=acceptable,request=request))
    originals = list(cases)
    for original in originals:
        changed = copy.deepcopy(original)
        changed['perturbation'] = 'reversed_same_state'
        changed['request']['request_id'] += '-reversed'
        changed['request']['candidates'].reverse()
        cases.append(changed)
    return {'rubric_version': 2,'interpretation': 'Feasible tactical plausibility, not a proof of game benefit. Local always delegates. All-safe cases are explicitly non-discriminative.', 'cases': cases}


def write_corpus(path):
    data = corpus()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, indent=2)+'\n')
    return data


def evaluate(data, split, output):
    rows = []
    for case in data['cases']:
      if case['split'] != split: continue
      request = urllib.request.Request('http://127.0.0.1:27878/decision',data=json.dumps(case['request']).encode(),headers={'Content-Type':'application/json'})
      try:
        with urllib.request.urlopen(request,timeout=10) as result: response=json.load(result)
      except urllib.error.HTTPError as error: response={'http_status':error.code,**json.load(error)}
      key=response.get('selected_candidate')
      rows.append({**case,'response':response,'acceptable_choice':key in case['acceptable'],
       'random_expected_acceptability':len(case['acceptable'])/len(case['request']['candidates']),
       'local_acceptable':'continue_local' in case['acceptable']})
    discriminative=[row for row in rows if row['random_expected_acceptability']<1]
    result={'split':split,'corpus_sha256':hashlib.sha256(json.dumps(data,sort_keys=True).encode()).hexdigest(),
      'n':len(rows),'discriminative_n':len(discriminative),'accepted':sum(row['acceptable_choice'] for row in rows),
      'discriminative_accepted':sum(row['acceptable_choice'] for row in discriminative),
      'random_expected_accepted':sum(row['random_expected_acceptability'] for row in rows),
      'local_accepted':sum(row['local_acceptable'] for row in rows),'rows':rows,
      'model_versions':list({row['response'].get('model_revision','error') for row in rows}),
      'permutation_pairs': [{'family':row['family'],'variant':row['variant'],
        'same_selection':row['response'].get('selected_candidate')==next(base['response'].get('selected_candidate') for base in rows if base['family']==row['family'] and base['variant']==row['variant'] and 'perturbation' not in base)} for row in rows if 'perturbation' in row]}
    result['family_results'] = {family: {'n':sum(row['family']==family for row in rows), 'accepted':sum(row['acceptable_choice'] for row in rows if row['family']==family), 'choices':[row['response'].get('selected_candidate') for row in rows if row['family']==family]} for family in sorted({row['family'] for row in rows})}
    result['uncertainty_note'] = 'Variants/order repeats are correlated. Only four heldout families; no statistical proof of general game intelligence.'
    output.parent.mkdir(parents=True,exist_ok=True)
    output.write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({key:value for key,value in result.items() if key!='rows'}))


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('command',choices=['corpus','evaluate'])
    parser.add_argument('--corpus',type=pathlib.Path,default=REPO/'work/policy-eval/scenarios.json')
    parser.add_argument('--split',choices=['development','heldout'],default='development')
    parser.add_argument('--out',type=pathlib.Path)
    args=parser.parse_args()
    if args.command=='corpus': write_corpus(args.corpus)
    else: evaluate(json.loads(args.corpus.read_text()),args.split,args.out or REPO/f'work/policy-eval/scenarios-{args.split}.json')
if __name__=='__main__': main()
