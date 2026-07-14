extends Node


const SETTINGS_PATH := "user://audio_settings.cfg"
const SFX_POOL_SIZE := 12
const MIN_DB := -80.0

const AUDIO_PATHS := {
	"tile_move": "res://assets/audio/sfx/tile_move.wav",
	"tile_spawn": "res://assets/audio/sfx/tile_spawn.wav",
	"merge": "res://assets/audio/sfx/merge.wav",
	"player_attack": "res://assets/audio/sfx/slash.wav",
	"enemy_hit": "res://assets/audio/sfx/enemy_hit.wav",
	"enemy_attack": "res://assets/audio/sfx/enemy_attack.wav",
	"player_hit": "res://assets/audio/sfx/player_hit.wav",
	"ultimate_charge": "res://assets/audio/sfx/ultimate_charge.wav",
	"ultimate": "res://assets/audio/sfx/ultimate.wav",
	"enemy_death": "res://assets/audio/sfx/enemy_death.wav",
	"stage_clear": "res://assets/audio/sfx/stage_clear.wav",
	"game_over": "res://assets/audio/sfx/game_over.wav",
	"upgrade_select": "res://assets/audio/sfx/upgrade_select.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"ultimate_full": "res://assets/audio/sfx/ultimate_full.wav",
	"break": "res://assets/audio/sfx/break.wav",
	"shield": "res://assets/audio/sfx/shield.wav",
}
const BGM_PATHS := {
	"battle": "res://assets/audio/bgm/battle.ogg",
	"upgrade": "res://assets/audio/bgm/upgrade.ogg",
	"game_over": "res://assets/audio/bgm/game_over.ogg",
}

var master_muted := false
var sfx_volume := 0.8
var bgm_volume := 0.45
var ui_volume := 0.65

var _streams: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _pool_cursor := 0
var _bgm_player: AudioStreamPlayer
var _current_bgm := ""
var _bgm_tween: Tween


func _ready() -> void:
	_build_players()
	_load_settings()
	_load_streams()
	_apply_bus_settings()


func play_ui_click() -> void:
	_play("ui_click", 1.0, 0.0, "UI")


func play_tile_move() -> void:
	_play("tile_move", 1.0, -9.0)


func play_tile_spawn() -> void:
	_play("tile_spawn", 1.0, -7.0)


func play_merge(tile_value: int, combo_index: int = 0) -> void:
	var value_steps := maxf(0.0, log(float(maxi(4, tile_value))) / log(2.0) - 2.0)
	var pitch := clampf(1.0 + value_steps * 0.055 + float(combo_index) * 0.05, 0.95, 1.5)
	var volume := clampf(-5.0 + value_steps * 0.35 - float(combo_index) * 0.8, -7.0, -2.0)
	_play("merge", pitch, volume)
	if combo_index >= 2:
		_play("enemy_hit", clampf(pitch * 0.72, 0.7, 1.0), -10.0)


func play_merge_sequence(values: Array) -> void:
	for index in range(values.size()):
		var delay := float(index) * 0.045
		var value := int(values[index])
		if delay <= 0.0:
			play_merge(value, index)
		else:
			var timer := get_tree().create_timer(delay)
			timer.timeout.connect(play_merge.bind(value, index))


func play_player_attack(power: int) -> void:
	_play("player_attack", clampf(0.95 + float(power) / 800.0, 0.95, 1.2), -5.0)


func play_enemy_hit(power: int, strong: bool = false) -> void:
	_play("enemy_hit", 0.82 if strong else 1.0, -2.0 if strong else -5.0)


func play_enemy_attack(power: int) -> void:
	_play("enemy_attack", clampf(0.9 + float(power) / 500.0, 0.9, 1.08), -5.0)


func play_player_hit(power: int) -> void:
	_play("player_hit", clampf(0.95 - float(power) / 1000.0, 0.8, 0.95), -4.0)


func play_ultimate() -> void:
	_play("ultimate_charge", 1.0, -5.0)
	_schedule_sound("ultimate", 0.16, 0.82, -1.0)
	_schedule_sound("enemy_hit", 0.34, 0.62, -3.0)


func play_enemy_death() -> void:
	_play("enemy_death", 0.82, -3.0)


func play_stage_clear() -> void:
	_play("stage_clear", 1.0, -2.0)


func play_game_over() -> void:
	_play("game_over", 0.82, -2.0)


func play_upgrade_open() -> void:
	_play("ui_click", 0.82, -5.0, "UI")


func play_upgrade_select(rarity: String = "Common") -> void:
	var pitch := 1.3 if rarity == "Epic" else (1.16 if rarity == "Rare" else 1.08)
	_play("upgrade_select", pitch, -3.0, "UI")


func play_ultimate_charge() -> void:
	_play("ultimate_charge", 1.35, -12.0)


func play_ultimate_full() -> void:
	_play("ultimate_full", 1.0, -3.0)


func play_break() -> void:
	_play("break", 0.9, -2.0)


func play_shield() -> void:
	_play("shield", 1.15, -4.0)

func play_meta_event(event_id: String) -> void:
	# Phase 3 events use existing procedural/optional streams, so missing assets
	# never block progression.
	match event_id:
		"soul", "unlock", "power": _play("upgrade_select", 1.2, -4.0, "UI")
		"speed": _play("merge", 1.3, -10.0)
		"fever": _play("ultimate_full", 1.08, -4.0)
		"debuff": _play("player_hit", 0.82, -6.0)
		_: _play("ui_click", 1.0, -8.0, "UI")


func play_bgm(track_id: String, fade_duration: float = 0.35) -> void:
	if track_id == _current_bgm and _bgm_player.playing:
		return
	var stream: AudioStream = _streams.get("bgm_" + track_id) as AudioStream
	if stream == null:
		return
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = AudioStreamWAV.LOOP_FORWARD
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	_current_bgm = track_id
	_bgm_player.stream = stream
	_bgm_player.volume_db = MIN_DB if fade_duration > 0.0 else 0.0
	_bgm_player.play()
	if fade_duration > 0.0:
		_bgm_tween = create_tween()
		_bgm_tween.tween_property(_bgm_player, "volume_db", 0.0, fade_duration)


func stop_bgm(fade_duration: float = 0.25) -> void:
	_current_bgm = ""
	if not _bgm_player.playing:
		return
	if _bgm_tween and _bgm_tween.is_valid():
		_bgm_tween.kill()
	if fade_duration <= 0.0:
		_bgm_player.stop()
		return
	_bgm_tween = create_tween()
	_bgm_tween.tween_property(_bgm_player, "volume_db", MIN_DB, fade_duration)
	_bgm_tween.finished.connect(_bgm_player.stop)


func set_master_volume(value: float) -> void:
	_set_bus_volume("Master", value)


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("SFX", sfx_volume)
	_save_settings()


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_set_bus_volume("BGM", bgm_volume)
	_save_settings()


func set_muted(enabled: bool) -> void:
	master_muted = enabled
	var index := AudioServer.get_bus_index("Master")
	if index >= 0:
		AudioServer.set_bus_mute(index, enabled)
	_save_settings()


func toggle_muted() -> bool:
	set_muted(not master_muted)
	return master_muted


func _build_players() -> void:
	for index in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.name = "SFX%02d" % index
		player.bus = "SFX"
		add_child(player)
		_sfx_players.append(player)
	_bgm_player = AudioStreamPlayer.new()
	_bgm_player.name = "BGM"
	_bgm_player.bus = "BGM"
	add_child(_bgm_player)


func _load_streams() -> void:
	for event_id: String in AUDIO_PATHS:
		var path: String = AUDIO_PATHS[event_id]
		_streams[event_id] = load(path) if ResourceLoader.exists(path) else _make_prototype_sound(event_id)
	for track_id: String in BGM_PATHS:
		var path: String = BGM_PATHS[track_id]
		if ResourceLoader.exists(path):
			_streams["bgm_" + track_id] = load(path)


func _play(event_id: String, pitch: float, volume_db: float, bus: String = "SFX") -> void:
	var stream: AudioStream = _streams.get(event_id) as AudioStream
	if stream == null or _sfx_players.is_empty():
		return
	var selected: AudioStreamPlayer
	for offset in range(_sfx_players.size()):
		var candidate := _sfx_players[(_pool_cursor + offset) % _sfx_players.size()]
		if not candidate.playing:
			selected = candidate
			_pool_cursor = (_pool_cursor + offset + 1) % _sfx_players.size()
			break
	if selected == null:
		selected = _sfx_players[_pool_cursor]
		_pool_cursor = (_pool_cursor + 1) % _sfx_players.size()
	selected.bus = bus
	selected.stream = stream
	selected.pitch_scale = clampf(pitch, 0.5, 2.0)
	selected.volume_db = volume_db
	selected.play()


func _schedule_sound(event_id: String, delay: float, pitch: float, volume_db: float) -> void:
	var timer := get_tree().create_timer(delay)
	timer.timeout.connect(_play.bind(event_id, pitch, volume_db, "SFX"))


func _make_prototype_sound(event_id: String) -> AudioStreamWAV:
	var profile: Dictionary = _prototype_profile(event_id)
	var frequency := float(profile["frequency"])
	var duration := float(profile["duration"])
	var wave := str(profile["wave"])
	var sample_rate := 22050
	var sample_count := int(duration * sample_rate)
	var data := PackedByteArray()
	data.resize(sample_count * 2)
	for index in range(sample_count):
		var t := float(index) / float(sample_rate)
		var envelope := pow(1.0 - float(index) / float(sample_count), 2.0)
		var phase := TAU * frequency * t
		var sample := sin(phase)
		if wave == "noise":
			sample = randf_range(-1.0, 1.0) * 0.75 + sin(phase) * 0.25
		elif wave == "square":
			sample = 1.0 if sin(phase) >= 0.0 else -1.0
		var value := clampi(int(sample * envelope * 12000.0), -32768, 32767)
		data.encode_s16(index * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = data
	return stream


func _prototype_profile(event_id: String) -> Dictionary:
	match event_id:
		"tile_move": return {"frequency": 180.0, "duration": 0.035, "wave": "noise"}
		"tile_spawn": return {"frequency": 520.0, "duration": 0.055, "wave": "sine"}
		"merge": return {"frequency": 420.0, "duration": 0.11, "wave": "sine"}
		"player_attack": return {"frequency": 260.0, "duration": 0.09, "wave": "noise"}
		"enemy_attack": return {"frequency": 170.0, "duration": 0.11, "wave": "square"}
		"enemy_hit": return {"frequency": 105.0, "duration": 0.13, "wave": "noise"}
		"player_hit": return {"frequency": 80.0, "duration": 0.16, "wave": "square"}
		"ultimate_charge": return {"frequency": 330.0, "duration": 0.22, "wave": "sine"}
		"ultimate": return {"frequency": 95.0, "duration": 0.38, "wave": "square"}
		"enemy_death": return {"frequency": 75.0, "duration": 0.22, "wave": "noise"}
		"stage_clear": return {"frequency": 660.0, "duration": 0.3, "wave": "sine"}
		"game_over": return {"frequency": 110.0, "duration": 0.38, "wave": "square"}
		"upgrade_select": return {"frequency": 760.0, "duration": 0.12, "wave": "sine"}
		"ultimate_full": return {"frequency": 880.0, "duration": 0.22, "wave": "sine"}
		"break": return {"frequency": 145.0, "duration": 0.24, "wave": "noise"}
		"shield": return {"frequency": 540.0, "duration": 0.16, "wave": "sine"}
		_: return {"frequency": 600.0, "duration": 0.06, "wave": "sine"}


func _apply_bus_settings() -> void:
	_set_bus_volume("SFX", sfx_volume)
	_set_bus_volume("BGM", bgm_volume)
	_set_bus_volume("UI", ui_volume)
	var master_index := AudioServer.get_bus_index("Master")
	if master_index >= 0:
		AudioServer.set_bus_mute(master_index, master_muted)


func _set_bus_volume(bus_name: String, value: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index >= 0:
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(clampf(value, 0.0, 1.0), 0.0001)))


func _load_settings() -> void:
	var config := ConfigFile.new()
	if config.load(SETTINGS_PATH) != OK:
		return
	master_muted = bool(config.get_value("audio", "master_muted", false))
	sfx_volume = clampf(float(config.get_value("audio", "sfx_volume", 0.8)), 0.0, 1.0)
	bgm_volume = clampf(float(config.get_value("audio", "bgm_volume", 0.45)), 0.0, 1.0)


func _save_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "master_muted", master_muted)
	config.set_value("audio", "sfx_volume", sfx_volume)
	config.set_value("audio", "bgm_volume", bgm_volume)
	var error := config.save(SETTINGS_PATH)
	if error != OK:
		push_warning("Could not save audio settings: %s" % error_string(error))
