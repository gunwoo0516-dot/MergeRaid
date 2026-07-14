class_name UpgradeSystem
extends RefCounted


const ORDERED_IDS: Array[String] = [
	"power_up",
	"combo_master",
	"vitality",
	"recovery",
	"ultimate_power",
	"fortify",
]

const DEFINITIONS: Dictionary = {
	"power_up": {
		"name": "Power Up",
		"icon": "ATK",
		"description": "All merge damage +20%",
		"max_level": 99,
	},
	"combo_master": {
		"name": "Combo Master",
		"icon": "x2",
		"description": "Combo bonus +25%",
		"max_level": 99,
	},
	"vitality": {
		"name": "Vitality",
		"icon": "HP",
		"description": "Max HP +20 and heal 20",
		"max_level": 10,
	},
	"recovery": {
		"name": "Recovery",
		"icon": "+",
		"description": "Stage clear healing +5",
		"max_level": 99,
	},
	"ultimate_power": {
		"name": "Ultimate Power",
		"icon": "ULT",
		"description": "Ultimate multiplier +0.5x",
		"max_level": 99,
	},
	"fortify": {
		"name": "Fortify",
		"icon": "DEF",
		"description": "Enemy attacks one move later",
		"max_level": 2,
	},
}


func generate_candidates(
	rng: RandomNumberGenerator,
	run_state: RunState,
	count: int = 3
) -> Array[String]:
	var available: Array[String] = []
	for upgrade_id: String in ORDERED_IDS:
		var definition: Dictionary = DEFINITIONS[upgrade_id]
		if run_state.get_upgrade_level(upgrade_id) < int(definition["max_level"]):
			available.append(upgrade_id)

	for index in range(available.size() - 1, 0, -1):
		var swap_index: int = rng.randi_range(0, index)
		var temporary: String = available[index]
		available[index] = available[swap_index]
		available[swap_index] = temporary

	var result: Array[String] = []
	for index in range(mini(count, available.size())):
		result.append(available[index])
	return result


func get_definition(upgrade_id: String) -> Dictionary:
	return DEFINITIONS.get(upgrade_id, {})


func get_change_text(upgrade_id: String, run_state: RunState) -> String:
	match upgrade_id:
		"power_up":
			return "%.1fx  →  %.1fx" % [
				run_state.attack_multiplier,
				run_state.attack_multiplier + 0.2,
			]
		"combo_master":
			return "%.2fx  →  %.2fx" % [
				run_state.combo_bonus_multiplier,
				run_state.combo_bonus_multiplier + 0.25,
			]
		"vitality":
			return "%d HP  →  %d HP" % [
				run_state.get_player_max_hp(),
				run_state.get_player_max_hp() + 20,
			]
		"recovery":
			return "+%d  →  +%d HP" % [
				run_state.stage_clear_heal,
				run_state.stage_clear_heal + 5,
			]
		"ultimate_power":
			return "%.1fx  →  %.1fx" % [
				run_state.ultimate_multiplier,
				run_state.ultimate_multiplier + 0.5,
			]
		"fortify":
			return "%d  →  %d moves" % [
				run_state.get_enemy_attack_interval(),
				run_state.get_enemy_attack_interval() + 1,
			]
	return ""
