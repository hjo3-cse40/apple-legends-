extends SceneTree

const Rules = preload("res://scenes/koth/koth_rules.gd")
var failures: Array[String] = []
var finished_signals := 0
var capture_signals := 0

func _init() -> void:
	call_deferred(&"_run")

func fresh() -> KothRules:
	var rules := Rules.new()
	rules.unlock_duration = 0.0
	rules.reset_match()
	return rules

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func near(actual: float, expected: float, message: String) -> void:
	check(absf(actual - expected) < 0.00001, "%s (%s vs %s)" % [message, actual, expected])

func _run() -> void:
	var r := fresh()
	r.unlock_duration = 15.0
	r.reset_match()
	r.advance(14.0, 1, 0)
	near(r.capture_progress, 0.0, "locked hill does not capture")
	r.advance(13.0, 1, 0)
	check(r.owner_team == Rules.CYAN, "lock and exact capture boundary handled in one frame")
	near(r.get_team_seconds(Rules.CYAN), 180.0, "capture frame not charged to newly owning clock")
	r = fresh()
	r.advance(6.0, 1, 0)
	near(r.capture_progress, 0.5, "12 second baseline")
	r.advance(50.0, 1, 1)
	near(r.capture_progress, 0.5, "contested neutral freezes capture")
	check(r.contested, "contest exposed")
	r.advance(3.0, 0, 0)
	near(r.capture_progress, 0.25, "empty point decays")
	r.advance(3.0, 0, 1)
	near(r.capture_progress, 0.0, "reversal erases old partial first")
	r.advance(12.0, 0, 1)
	check(r.owner_team == Rules.AMBER, "amber can capture after reversal")
	r.advance(10.0, 0, 0)
	near(r.get_team_seconds(Rules.AMBER), 170.0, "owned empty zone holds clock")
	r.advance(10.0, 1, 1)
	near(r.get_team_seconds(Rules.AMBER), 170.0, "contest freezes owner clock")
	r.advance(6.0, 1, 0)
	near(r.capture_progress, 0.5, "sole enemy attacks owned point")
	near(r.get_team_seconds(Rules.AMBER), 164.0, "owner clock runs through sole attack")
	r.advance(6.0, 0, 1)
	near(r.capture_progress, 0.0, "defender erases enemy partial")
	check(r.capturing_team == Rules.NEUTRAL, "erased progress releases capture team")
	r.advance(15.0, 1, 0)
	check(r.owner_team == Rules.CYAN, "clock transfers at capture")
	near(r.get_team_seconds(Rules.AMBER), 146.0, "old owner clock counted only pretransfer time")
	near(r.get_team_seconds(Rules.CYAN), 177.0, "new owner clock counts posttransfer remainder")
	r.advance(12.0, 0, 1)
	near(r.get_team_seconds(Rules.AMBER), 146.0, "recapture preserves old remaining clock")
	r = fresh()
	r.advance(8.0, 2, 0)
	check(r.owner_team == Rules.CYAN, "two players capture at harmonic 1.5x")
	r = fresh()
	r.advance(12.0 / (1.0 + 0.5 + 1.0 / 3.0), 3, 0)
	check(r.owner_team == Rules.CYAN, "three players harmonic pacing")
	r = fresh()
	r.advance(6.0, 1, 0)
	r.advance(18.0, 0, 1)
	check(r.owner_team == Rules.AMBER, "large reversal frame erases then captures")
	r = fresh()
	r.round_duration = 5.0
	r.reset_match()
	r.point_captured.connect(func(_team: int): capture_signals += 1)
	r.match_finished.connect(func(_team: int): finished_signals += 1)
	r.advance(12.0, 1, 0)
	r.advance(5.0, 0, 1)
	check(r.overtime and not r.match_over, "zero owner clock with attacker starts overtime")
	r.advance(3.0, 1, 1)
	check(r.overtime and not r.match_over, "contested overtime continues")
	r.advance(7.0, 0, 1)
	check(r.owner_team == Rules.AMBER and not r.match_over, "attacker captures in overtime")
	r.advance(5.0, 0, 0)
	check(r.match_over and r.winner_team == Rules.AMBER, "unopposed zero clock wins")
	r.advance(100.0, 1, 0)
	check(finished_signals == 1 and capture_signals == 2, "signals fire once per actual event")
	r.reset_match()
	check(not r.match_over and r.winner_team == Rules.NEUTRAL and not r.overtime, "reset clears terminal state")
	r = fresh()
	r.advance(12.0, 1, 0)
	r.advance(180.0, 1, 1)
	near(r.get_team_seconds(Rules.CYAN), 180.0, "contest stops clock for arbitrarily long intervals")
	r.advance(180.0, 0, 0)
	check(r.match_over and r.winner_team == Rules.CYAN, "cyan empty-point victory")
	r = fresh()
	r.round_duration = 1.0
	r.reset_match()
	r.advance(12.0, 1, 0)
	r.advance(1.0, 0, 1)
	r.advance(0.0, 0, 0)
	check(r.match_over, "zero-delta occupancy update resolves overtime when enemy leaves")
	r = fresh()
	r.advance(-1.0, 1, 0)
	r.advance(INF, 1, 0)
	r.advance(NAN, 1, 0)
	r.advance(100.0, -2, -3)
	check(r.owner_team == Rules.NEUTRAL and r.capture_progress == 0.0, "invalid deltas ignored and counts clamped")
	var snap := r.get_snapshot()
	snap.team_seconds_remaining[Rules.CYAN] = -1.0
	near(r.get_team_seconds(Rules.CYAN), 180.0, "snapshot is detached")
	# Same occupancy timeline with a coarse frame and many small frames must agree.
	for trial in range(60):
		var coarse := fresh()
		var fine := fresh()
		coarse.unlock_duration = 2.7
		fine.unlock_duration = 2.7
		coarse.reset_match()
		fine.reset_match()
		for segment in range(30):
			var cyan := (trial * 7 + segment * 3) % 4
			var amber := (trial * 3 + segment * 7 + 1) % 4
			var duration := 0.13 + float((trial + segment * 11) % 130) * 0.19
			coarse.advance(duration, cyan, amber)
			for part in range(19):
				fine.advance(duration / 19.0, cyan, amber)
		check(coarse.owner_team == fine.owner_team and coarse.capturing_team == fine.capturing_team, "partition ownership trial %s" % trial)
		check(coarse.match_over == fine.match_over and coarse.winner_team == fine.winner_team and coarse.overtime == fine.overtime, "partition terminal state trial %s" % trial)
		near(coarse.capture_progress, fine.capture_progress, "partition capture trial %s" % trial)
		near(coarse.get_team_seconds(Rules.CYAN), fine.get_team_seconds(Rules.CYAN), "partition cyan trial %s" % trial)
		near(coarse.get_team_seconds(Rules.AMBER), fine.get_team_seconds(Rules.AMBER), "partition amber trial %s" % trial)
	if failures.is_empty():
		print("KOTH rules smoke: PASS (boundary scenarios and 60 partition timelines)")
		quit(0)
	else:
		for failure in failures:
			push_error(failure)
		quit(1)
