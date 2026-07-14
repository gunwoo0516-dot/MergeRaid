class_name RunState
extends RefCounted


const BASE_PLAYER_HP: int = 100
const BASE_STAGE_HEAL: int = 15
const BASE_ENEMY_ATTACK_INTERVAL: int = 3
const BASE_ULTIMATE_MULTIPLIER: float = 2.0

var attack_multiplier: float = 1.0
var combo_bonus_multiplier: float = 1.0
var max_hp_bonus: int = 0
var stage_clear_heal: int = BASE_STAGE_HEAL
var ultimate_multiplier: float = BASE_ULTIMATE_MULTIPLIER
var enemy_attack_interval_bonus: int = 0
var permanent_attack_multiplier: float = 1.0
var upgrade_levels: Dictionary = {}
var current_stage: int = 1


func reset_for_new_run(permanent_multiplier: float = 1.0) -> void:
	attack_multiplier = 1.0
	combo_bonus_multiplier = 1.0
	max_hp_bonus = 0
	stage_clear_heal = BASE_STAGE_HEAL
	ultimate_multiplier = BASE_ULTIMATE_MULTIPLIER
	enemy_attack_interval_bonus = 0
	permanent_attack_multiplier = permanent_multiplier
	upgrade_levels.clear()
	current_stage = 1


func apply_upgrade(upgrade_id: String) -> void:
	upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	match upgrade_id:
		"power_up":
			attack_multiplier += 0.2
		"combo_master":
			combo_bonus_multiplier += 0.25
		"vitality":
			max_hp_bonus += 20
		"recovery":
			stage_clear_heal += 5
		"ultimate_power":
			ultimate_multiplier += 0.5
		"fortify":
			enemy_attack_interval_bonus += 1


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_final_attack_damage(base_damage: int, base_combo_bonus: int) -> int:
	var combo_bonus: int = get_final_combo_bonus(base_combo_bonus)
	return roundi(
		float(base_damage + combo_bonus)
		* attack_multiplier
		* permanent_attack_multiplier
	)


func get_final_combo_bonus(base_bonus: int) -> int:
	return roundi(float(base_bonus) * combo_bonus_multiplier)


func get_final_ultimate_damage(tile_value: int) -> int:
	return roundi(
		float(tile_value)
		* ultimate_multiplier
		* permanent_attack_multiplier
	)


func get_player_max_hp() -> int:
	return BASE_PLAYER_HP + max_hp_bonus


func get_enemy_attack_interval() -> int:
	return BASE_ENEMY_ATTACK_INTERVAL + enemy_attack_interval_bonus
