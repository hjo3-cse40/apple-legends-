class_name CombatAudioTuning
extends RefCounted
## Shared world-gun presentation: host bots and replicated actors must sound alike.
const SHOT_VOLUME_DB := 1.0
const SHOT_UNIT_SIZE := 20.0
const SHOT_MAX_DISTANCE := 100.0

static func configure_world_shot(sound: AudioStreamPlayer3D) -> void:
	sound.volume_db = SHOT_VOLUME_DB
	sound.unit_size = SHOT_UNIT_SIZE
	sound.max_distance = SHOT_MAX_DISTANCE
	sound.attenuation_filter_cutoff_hz = 10000.0
	sound.max_polyphony = 3
