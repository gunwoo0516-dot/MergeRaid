class_name RunState
extends RefCounted


const BASE_PLAYER_HP := 100
const BASE_STAGE_HEAL := 10
const BASE_ENEMY_ATTACK_INTERVAL := 3
const BASE_BREAK_CHARGES := 1
const BASE_ULTIMATE_MULTIPLIER := 2.0

var attack_bonus_percent := 0
var combo_bonus_percent := 0
var max_hp_bonus := 0
var stage_clear_heal := BASE_STAGE_HEAL
var ultimate_damage_bonus_percent := 0
var ultimate_charge_bonus_percent := 0
var enemy_attack_interval_bonus := 0
var break_max_charges := BASE_BREAK_CHARGES
var break_current_charges := BASE_BREAK_CHARGES
var shield := 0
var upgrade_levels: Dictionary = {}
var current_stage := 1
var largest_tile := 0
var large_tile_bonus_percent := 0
var overflow_stacks := 0
var emergency_shield_used_this_stage := false
var second_wind_used := false
var first_attack_this_stage := true
var consecutive_merge_turns := 0
var focus_ready := false


func reset_for_new_run() -> void:
	attack_bonus_percent = 0
	combo_bonus_percent = 0
	max_hp_bonus = 0
	stage_clear_heal = BASE_STAGE_HEAL
	ultimate_damage_bonus_percent = 0
	ultimate_charge_bonus_percent = 0
	enemy_attack_interval_bonus = 0
	break_max_charges = BASE_BREAK_CHARGES
	break_current_charges = BASE_BREAK_CHARGES
	shield = 0
	upgrade_levels.clear()
	current_stage = 1
	largest_tile = 0
	large_tile_bonus_percent = 0
	overflow_stacks = 0
	emergency_shield_used_this_stage = false
	second_wind_used = false
	first_attack_this_stage = true
	consecutive_merge_turns = 0
	focus_ready = false


func apply_upgrade(upgrade_id: String) -> void:
	upgrade_levels[upgrade_id] = get_upgrade_level(upgrade_id) + 1
	match upgrade_id:
		"power_up": attack_bonus_percent += 15
		"combo_master": combo_bonus_percent += 20
		"vitality": max_hp_bonus += 20
		"recovery": stage_clear_heal += 10
		"fast_charge": ultimate_charge_bonus_percent += 20
		"ultimate_power": ultimate_damage_bonus_percent += 25
		"break_charge":
			break_max_charges += 1
			break_current_charges += 1
		"stage_preparation": pass
		_: pass


func get_upgrade_level(upgrade_id: String) -> int:
	return int(upgrade_levels.get(upgrade_id, 0))


func get_player_max_hp(base_hp: int = BASE_PLAYER_HP) -> int:
	return base_hp + max_hp_bonus


func update_largest_tile(value: int) -> void:
	largest_tile = value
	var base_bonus := 0
	if value >= 1024: base_bonus = 50
	elif value >= 512: base_bonus = 40
	elif value >= 256: base_bonus = 30
	elif value >= 128: base_bonus = 20
	elif value >= 64: base_bonus = 10
	var giant_level := get_upgrade_level("giant_strength")
	large_tile_bonus_percent = base_bonus + (giant_level * 4 if base_bonus > 0 else 0)


func get_final_merge_damage(base_damage: int, base_combo_bonus: int, context: Dictionary = {}) -> int:
	var combo := base_combo_bonus
	combo += roundi(float(base_damage) * float(combo_bonus_percent) / 100.0)
	var additive_percent := attack_bonus_percent + large_tile_bonus_percent
	var largest_merge := int(context.get("largest_merge", 0))
	var merge_count := int(context.get("merge_count", 1))
	if largest_merge >= 32:
		additive_percent += get_upgrade_level("heavy_strike") * 25
		combo += get_upgrade_level("critical_edge") * 6
	if first_attack_this_stage:
		additive_percent += get_upgrade_level("first_blood") * 30
	if merge_count >= 2:
		additive_percent += get_upgrade_level("chain_slash") * 12
	if consecutive_merge_turns >= 2:
		additive_percent += get_upgrade_level("rhythm_attack") * 10
	if focus_ready:
		additive_percent += get_upgrade_level("battle_focus") * 20
	var finisher_level := get_upgrade_level("finisher")
	if finisher_level > 0:
		combo += roundi(float(largest_merge) * float(finisher_level) * 0.12)
	return maxi(1, roundi(float(base_damage + combo) * (1.0 + float(additive_percent) / 100.0)))


func get_final_combo_bonus(base_bonus: int) -> int:
	return base_bonus + roundi(float(base_bonus) * float(combo_bonus_percent) / 100.0)


func get_final_ultimate_damage(base_damage: int) -> int:
	var overflow_bonus := overflow_stacks * get_upgrade_level("overflow") * 12
	var additive := ultimate_damage_bonus_percent + large_tile_bonus_percent + overflow_bonus
	return maxi(1, roundi(float(base_damage) * (1.0 + float(additive) / 100.0) * BASE_ULTIMATE_MULTIPLIER))


func get_ultimate_charge_gain(base_gain: float) -> float:
	var bonus := ultimate_charge_bonus_percent
	if largest_tile >= 256:
		bonus += get_upgrade_level("arcane_core") * 15
	return base_gain * (1.0 + float(bonus) / 100.0)


func get_enemy_attack_interval(base_interval: int = BASE_ENEMY_ATTACK_INTERVAL) -> int:
	return maxi(2, base_interval + enemy_attack_interval_bonus)


func get_enemy_damage(raw_damage: int) -> int:
	var reduction := get_upgrade_level("tough_skin") * 8
	if largest_tile >= 128:
		reduction += get_upgrade_level("stable_core") * 8
	return maxi(1, roundi(float(raw_damage) * (1.0 - minf(0.65, float(reduction) / 100.0))))


func absorb_damage(raw_damage: int, current_hp: int) -> Dictionary:
	var damage := get_enemy_damage(raw_damage)
	var absorbed := mini(shield, damage)
	shield -= absorbed
	damage -= absorbed
	var emergency_level := get_upgrade_level("emergency_shield")
	if emergency_level > 0 and not emergency_shield_used_this_stage and current_hp - damage <= get_player_max_hp() * 0.35:
		shield += emergency_level * 12
		emergency_shield_used_this_stage = true
		var extra_absorb := mini(shield, damage)
		shield -= extra_absorb
		absorbed += extra_absorb
		damage -= extra_absorb
	var prevented_death := false
	if damage >= current_hp and get_upgrade_level("second_wind") > 0 and not second_wind_used:
		damage = maxi(0, current_hp - 1)
		second_wind_used = true
		prevented_death = true
	return {"hp_damage": damage, "absorbed": absorbed, "prevented_death": prevented_death}


func begin_stage() -> Dictionary:
	first_attack_this_stage = true
	emergency_shield_used_this_stage = false
	var level := get_upgrade_level("stage_preparation")
	var heal := level * 4
	var shield_gain := level * 6
	shield += shield_gain
	return {"heal": heal, "shield": shield_gain}


func record_move(had_merge: bool) -> void:
	if had_merge:
		consecutive_merge_turns += 1
		focus_ready = false
	else:
		consecutive_merge_turns = 0
		focus_ready = get_upgrade_level("battle_focus") > 0


func consume_attack_flags() -> void:
	first_attack_this_stage = false
	focus_ready = false


func get_build_summary() -> Array[String]:
	var lines: Array[String] = []
	for upgrade_id: String in upgrade_levels:
		var level := get_upgrade_level(upgrade_id)
		if level > 0:
			lines.append("%s Lv.%d" % [upgrade_id, level])
	return lines
