class_name SaveManager
extends RefCounted


const SAVE_PATH: String = "user://merge_battle_progress.cfg"
const SOULS_PER_LEVEL: int = 5
const MAX_PERMANENT_LEVEL: int = 10

var total_souls: int = 0
var best_stage: int = 1
var total_runs: int = 0
var permanent_attack_level: int = 0


func load_save() -> void:
	_reset_values()
	var config := ConfigFile.new()
	var error: Error = config.load(SAVE_PATH)
	if error != OK:
		return

	total_souls = _read_non_negative_int(config, "total_souls", 0)
	best_stage = maxi(1, _read_non_negative_int(config, "best_stage", 1))
	total_runs = _read_non_negative_int(config, "total_runs", 0)
	_recalculate_permanent_level()


func save_game() -> void:
	var config := ConfigFile.new()
	config.set_value("meta", "total_souls", total_souls)
	config.set_value("meta", "best_stage", best_stage)
	config.set_value("meta", "total_runs", total_runs)
	config.set_value("meta", "permanent_attack_level", permanent_attack_level)
	var error: Error = config.save(SAVE_PATH)
	if error != OK:
		push_warning("Could not save meta progression: %s" % error_string(error))


func add_soul(amount: int) -> void:
	total_souls = maxi(0, total_souls + amount)
	_recalculate_permanent_level()
	save_game()


func record_run(reached_stage: int) -> void:
	total_runs += 1
	best_stage = maxi(best_stage, reached_stage)
	save_game()


func record_stage_progress(reached_stage: int) -> void:
	best_stage = maxi(best_stage, reached_stage)
	save_game()


func get_permanent_attack_multiplier() -> float:
	return 1.0 + float(permanent_attack_level) * 0.05


func reset_save_for_debug() -> void:
	_reset_values()
	save_game()


func _recalculate_permanent_level() -> void:
	permanent_attack_level = mini(
		floori(float(total_souls) / float(SOULS_PER_LEVEL)),
		MAX_PERMANENT_LEVEL
	)


func _reset_values() -> void:
	total_souls = 0
	best_stage = 1
	total_runs = 0
	permanent_attack_level = 0


func _read_non_negative_int(
	config: ConfigFile,
	key: String,
	default_value: int
) -> int:
	var value: Variant = config.get_value("meta", key, default_value)
	if value is int or value is float:
		return maxi(0, int(value))
	return default_value
