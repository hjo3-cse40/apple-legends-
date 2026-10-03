class_name KothRules
extends RefCounted
## Pure objective simulation. Occupancy counts include living players only.

signal state_changed
signal point_captured(team: int)
signal match_finished(team: int)

const NEUTRAL := 0
const CYAN := 1
const AMBER := 2
const EPSILON := 0.0000001

var capture_duration := 12.0
var round_duration := 180.0
var unlock_duration := 15.0
var owner_team := NEUTRAL
var capturing_team := NEUTRAL
var capture_progress := 0.0
var team_seconds_remaining: Dictionary = {CYAN: 180.0, AMBER: 180.0}
var contested := false
var match_over := false
var winner_team := NEUTRAL
var unlock_remaining := 15.0
var overtime := false


func reset_match() -> void:
	owner_team = NEUTRAL
	capturing_team = NEUTRAL
	capture_progress = 0.0
	team_seconds_remaining = {CYAN: maxf(round_duration, 0.0), AMBER: maxf(round_duration, 0.0)}
	contested = false
	match_over = false
	winner_team = NEUTRAL
	unlock_remaining = maxf(unlock_duration, 0.0)
	overtime = false
	state_changed.emit()


func get_team_seconds(team: int) -> float:
	return float(team_seconds_remaining.get(team, 0.0))


func get_snapshot() -> Dictionary:
	return {
		"owner_team": owner_team, "capturing_team": capturing_team,
		"capture_progress": capture_progress, "team_seconds_remaining": team_seconds_remaining.duplicate(),
		"contested": contested, "match_over": match_over, "winner_team": winner_team,
		"unlock_remaining": unlock_remaining, "overtime": overtime,
	}


func advance(delta: float, cyan_count: int, amber_count: int) -> void:
	if match_over or not is_finite(delta) or delta < 0.0:
		return
	cyan_count = maxi(cyan_count, 0)
	amber_count = maxi(amber_count, 0)
	contested = cyan_count > 0 and amber_count > 0
	var remaining := delta
	if unlock_remaining > 0.0:
		var locked_step := minf(remaining, unlock_remaining)
		unlock_remaining = maxf(unlock_remaining - locked_step, 0.0)
		remaining -= locked_step
	if unlock_remaining > 0.0:
		state_changed.emit()
		return
	var occupying_team := NEUTRAL
	if not contested:
		if cyan_count > 0:
			occupying_team = CYAN
		elif amber_count > 0:
			occupying_team = AMBER
	# Split time at ownership and clock boundaries: capture time cannot count as hold time.
	while not match_over:
		var enemy_present := owner_team != NEUTRAL and (amber_count > 0 if owner_team == CYAN else cyan_count > 0)
		overtime = owner_team != NEUTRAL and get_team_seconds(owner_team) <= EPSILON and enemy_present
		if owner_team != NEUTRAL and get_team_seconds(owner_team) <= EPSILON and not enemy_present:
			_finish(owner_team)
			break
		if contested or remaining <= EPSILON:
			break
		var cap_rate := 0.0
		var duration := maxf(capture_duration, EPSILON)
		if occupying_team != NEUTRAL and occupying_team != owner_team:
			if capturing_team == NEUTRAL:
				capturing_team = occupying_team
			var occupants := cyan_count if occupying_team == CYAN else amber_count
			var multiplier := _capture_multiplier(occupants)
			cap_rate = multiplier / duration if capturing_team == occupying_team else -multiplier / duration
		elif capture_progress > 0.0:
			cap_rate = -1.0 / duration
		var step := remaining
		if cap_rate > 0.0:
			step = minf(step, (1.0 - capture_progress) / cap_rate)
		elif cap_rate < 0.0:
			step = minf(step, capture_progress / -cap_rate)
		if owner_team != NEUTRAL and get_team_seconds(owner_team) > EPSILON:
			step = minf(step, get_team_seconds(owner_team))
		capture_progress = clampf(capture_progress + cap_rate * step, 0.0, 1.0)
		if owner_team != NEUTRAL:
			team_seconds_remaining[owner_team] = maxf(get_team_seconds(owner_team) - step, 0.0)
		remaining = maxf(remaining - step, 0.0)
		if cap_rate > 0.0 and capture_progress >= 1.0 - EPSILON:
			owner_team = capturing_team
			capturing_team = NEUTRAL
			capture_progress = 0.0
			overtime = false
			point_captured.emit(owner_team)
		elif cap_rate < 0.0 and capture_progress <= EPSILON:
			capture_progress = 0.0
			capturing_team = NEUTRAL
	state_changed.emit()


func _capture_multiplier(occupants: int) -> float:
	# TF2 capture scaling has diminishing returns: 1, 1.5, 1.833..., capped at 3.
	var multiplier := 0.0
	for index in range(mini(occupants, 11)):
		multiplier += 1.0 / float(index + 1)
	return minf(multiplier, 3.0)


func _finish(team: int) -> void:
	match_over = true
	winner_team = team
	overtime = false
	match_finished.emit(team)
