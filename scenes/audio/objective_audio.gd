class_name ObjectiveAudio
extends Node
## Global, non-spatial announcer. Warnings follow retained team clocks, not wall time.

signal cue_requested(key: String, caption: String)
const THRESHOLDS := [30, 10, 5, 4, 3, 2, 1]
const NUMBERS := {5: "five", 4: "four", 3: "three", 2: "two", 1: "one"}
@export_range(-30.0, 0.0, 1.0) var voice_volume_db := -5.0
@export_range(-30.0, 0.0, 1.0) var chime_volume_db := -9.0
var voice: AudioStreamPlayer
var chime: AudioStreamPlayer
var _previous_times: Dictionary = {}
var _announced: Dictionary = {}
var _was_contested := false
var _was_overtime := false
var _contest_cooldown := 0.0
var _streams: Dictionary = {}

func _ready() -> void:
	voice = AudioStreamPlayer.new()
	voice.name = "GlobalAnnouncer"
	voice.volume_db = voice_volume_db
	add_child(voice)
	chime = AudioStreamPlayer.new()
	chime.name = "ObjectiveChime"
	chime.volume_db = chime_volume_db
	add_child(chime)
	for key in ["capture_cyan", "capture_amber", "cyan_30", "amber_30", "cyan_10", "amber_10", "five", "four", "three", "two", "one", "overtime", "capture_cyan_chime", "capture_amber_chime", "contest_chime", "overtime_chime"]:
		_streams[key] = load("res://audio/objective/%s.wav" % key)

func reset_round(snapshot: Dictionary) -> void:
	voice.stop()
	chime.stop()
	_previous_times = snapshot["team_seconds_remaining"].duplicate()
	_announced.clear()
	_was_contested = false
	_was_overtime = false
	_contest_cooldown = 0.0

func point_captured(team: int) -> void:
	var team_name := "cyan" if team == KothRules.CYAN else "amber"
	_play_chime("capture_%s_chime" % team_name)
	_announce("capture_%s" % team_name, "%s CAPTURED THE POINT" % team_name.to_upper())

func observe(snapshot: Dictionary, delta: float) -> void:
	_contest_cooldown = maxf(0.0, _contest_cooldown - delta)
	var times: Dictionary = snapshot["team_seconds_remaining"]
	if bool(snapshot["match_over"]):
		voice.stop()
		_previous_times = times.duplicate()
		return
	var contested := bool(snapshot["contested"]) and float(snapshot["unlock_remaining"]) <= 0.0
	if contested and not _was_contested and _contest_cooldown <= 0.0:
		_play_chime("contest_chime")
		cue_requested.emit("contest", "POINT CONTESTED")
		_contest_cooldown = 4.0
	var overtime := bool(snapshot["overtime"])
	if overtime and not _was_overtime:
		_play_chime("overtime_chime")
		_announce("overtime", "OVERTIME — CLEAR THE POINT")
	for team in [KothRules.CYAN, KothRules.AMBER]:
		var previous := float(_previous_times.get(team, times[team]))
		var current := float(times[team])
		var crossed := 0
		for threshold in THRESHOLDS:
			var id := "%d:%d" % [team, threshold]
			if previous > float(threshold) + KothRules.EPSILON and current <= float(threshold) + KothRules.EPSILON and not _announced.has(id):
				_announced[id] = true
				crossed = threshold
		# A large simulation step emits only the latest relevant warning, never a backlog.
		if crossed > 0 and current > KothRules.EPSILON and not overtime:
			var name := "cyan" if team == KothRules.CYAN else "amber"
			var key := "%s_%d" % [name, crossed] if crossed >= 10 else str(NUMBERS[crossed])
			_announce(key, "%s — %d SECONDS TO VICTORY" % [name.to_upper(), crossed])
	_previous_times = times.duplicate()
	_was_contested = contested
	_was_overtime = overtime

func _announce(key: String, caption: String) -> void:
	# Fresh urgency replaces stale speech, especially at overtime and final seconds.
	voice.stream = _streams[key] as AudioStream
	voice.play()
	cue_requested.emit(key, caption)

func _play_chime(key: String) -> void:
	chime.stream = _streams[key] as AudioStream
	chime.play()
