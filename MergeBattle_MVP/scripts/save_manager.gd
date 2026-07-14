class_name SaveManager
extends RefCounted

const SAVE_PATH := "user://merge_battle_progress.cfg"
const SAVE_VERSION := 3
const POWER_COST := 5
const MAX_POWER_LEVEL := 10
const DEFAULT_UNLOCKS: Array[String] = ["steady_start"]

var souls := 0
var best_stage := 1
var total_runs := 0
var total_stage_clears := 0
var permanent_power_level := 0
var unlocked_content: Array[String] = []
var audio_settings: Dictionary = {}
var first_launch_completed := false
var last_starting_passive := "steady_start"

func load_save() -> void:
	_reset_defaults()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	# Phase 2 compatibility: total_souls was lifetime currency and power was derived.
	var version := _read_int(config, "save_version", 1)
	if version < 3:
		souls = _read_int(config, "souls", _read_int(config, "total_souls", 0))
		permanent_power_level = clampi(_read_int(config, "permanent_power_level", 0), 0, MAX_POWER_LEVEL)
	else:
		souls = _read_int(config, "souls", 0)
		permanent_power_level = clampi(_read_int(config, "permanent_power_level", 0), 0, MAX_POWER_LEVEL)
	best_stage = maxi(1, _read_int(config, "best_stage", 1))
	total_runs = _read_int(config, "total_runs", 0)
	total_stage_clears = _read_int(config, "total_stage_clears", 0)
	var raw_unlocks: Variant = config.get_value("meta", "unlocked_content", DEFAULT_UNLOCKS)
	if raw_unlocks is Array:
		for raw: Variant in raw_unlocks:
			var content_id := str(raw)
			if not content_id.is_empty() and content_id not in unlocked_content:
				unlocked_content.append(content_id)
	for content_id: String in DEFAULT_UNLOCKS:
		if content_id not in unlocked_content: unlocked_content.append(content_id)
	var raw_audio: Variant = config.get_value("meta", "audio_settings", {})
	if raw_audio is Dictionary: audio_settings = raw_audio.duplicate(true)
	first_launch_completed = bool(config.get_value("meta", "first_launch_completed", false))
	last_starting_passive = str(config.get_value("meta", "last_starting_passive", "steady_start"))

func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "save_version", SAVE_VERSION)
	config.set_value("meta", "souls", souls)
	config.set_value("meta", "best_stage", best_stage)
	config.set_value("meta", "total_runs", total_runs)
	config.set_value("meta", "total_stage_clears", total_stage_clears)
	config.set_value("meta", "permanent_power_level", permanent_power_level)
	config.set_value("meta", "unlocked_content", unlocked_content)
	config.set_value("meta", "audio_settings", audio_settings)
	config.set_value("meta", "first_launch_completed", first_launch_completed)
	config.set_value("meta", "last_starting_passive", last_starting_passive)
	var error := config.save(SAVE_PATH)
	if error != OK: push_warning("Could not save meta progression: %s" % error_string(error))

func reset_save_for_debug() -> void:
	_reset_defaults()
	save_game()

func add_souls(amount: int) -> void:
	souls = maxi(0, souls + amount)
	save_game()

func spend_souls(amount: int) -> bool:
	if amount < 0 or souls < amount: return false
	souls -= amount
	save_game()
	return true

func buy_permanent_power() -> bool:
	if permanent_power_level >= MAX_POWER_LEVEL or not spend_souls(POWER_COST): return false
	permanent_power_level += 1
	save_game()
	return true

func record_run(reached_stage: int) -> void:
	total_runs += 1
	best_stage = maxi(best_stage, reached_stage)
	save_game()

func record_stage_clear() -> void:
	total_stage_clears += 1
	save_game()

func unlock_content(content_id: String) -> void:
	if content_id not in unlocked_content:
		unlocked_content.append(content_id)
		save_game()

func is_unlocked(content_id: String) -> bool:
	return content_id in unlocked_content

func get_permanent_attack_bonus_percent() -> int:
	return mini(50, permanent_power_level * 5)

func _reset_defaults() -> void:
	souls = 0; best_stage = 1; total_runs = 0; total_stage_clears = 0
	permanent_power_level = 0; unlocked_content = DEFAULT_UNLOCKS.duplicate()
	audio_settings = {}; first_launch_completed = false; last_starting_passive = "steady_start"

func _read_int(config: ConfigFile, key: String, fallback: int) -> int:
	var value: Variant = config.get_value("meta", key, fallback)
	return maxi(0, int(value)) if value is int or value is float else fallback
