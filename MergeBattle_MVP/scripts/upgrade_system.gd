class_name UpgradeSystem
extends RefCounted


const RARITY_WEIGHTS := {"Common": 65.0, "Rare": 28.0, "Epic": 7.0}
const ORDERED_IDS: Array[String] = [
	"power_up", "heavy_strike", "critical_edge", "first_blood",
	"combo_master", "chain_slash", "finisher", "rhythm_attack",
	"vitality", "recovery", "tough_skin", "emergency_shield", "second_wind",
	"fast_charge", "ultimate_power", "overflow", "aftershock",
	"giant_strength", "stable_core", "arcane_core",
	"break_charge", "small_start", "battle_focus", "stage_preparation",
	"quick_step", "momentum", "fever_charge", "fever_power", "long_fever", "hot_start",
]

static var DEFINITIONS: Dictionary = {
	"power_up": _d("Power Up", "Attack", "All merge damage +15%", 5, "Common", 65, "ATK"),
	"heavy_strike": _d("Heavy Strike", "Attack", "32+ merges gain +25% damage", 4, "Rare", 28, "32+"),
	"critical_edge": _d("Critical Edge", "Attack", "32+ merges add 6 fixed damage", 4, "Rare", 28, "+6"),
	"first_blood": _d("First Blood", "Attack", "First attack each stage +30%", 3, "Rare", 28, "1ST"),
	"combo_master": _d("Combo Master", "Combo", "Combo bonus +20%", 5, "Common", 65, "x2"),
	"chain_slash": _d("Chain Slash", "Combo", "2+ merges gain +12% damage", 3, "Rare", 28, "CHN"),
	"finisher": _d("Finisher", "Combo", "Last merge adds 12% as damage", 4, "Rare", 28, "FIN"),
	"rhythm_attack": _d("Rhythm Attack", "Combo", "Consecutive merge turns +10%", 3, "Common", 65, "RHY"),
	"vitality": _d("Vitality", "Survival", "Max HP +20 and heal 20", 5, "Common", 65, "HP"),
	"recovery": _d("Recovery", "Survival", "Stage clear healing +10", 5, "Common", 65, "+HP"),
	"tough_skin": _d("Tough Skin", "Survival", "Enemy damage -8%", 4, "Common", 65, "DEF"),
	"emergency_shield": _d("Emergency Shield", "Survival", "Low HP grants 12 shield once/stage", 3, "Rare", 28, "SHD"),
	"second_wind": _d("Second Wind", "Survival", "Survive lethal damage once per run", 1, "Epic", 7, "1UP"),
	"fast_charge": _d("Fast Charge", "Ultimate", "Ultimate charge +20%", 5, "Common", 65, "FAST"),
	"ultimate_power": _d("Ultimate Power", "Ultimate", "Ultimate damage +25%", 5, "Rare", 28, "ULT"),
	"overflow": _d("Overflow", "Ultimate", "Full-gauge merges empower next Ultimate", 3, "Epic", 7, "OVR"),
	"aftershock": _d("Aftershock", "Ultimate", "Ultimate adds a 12% aftershock", 3, "Rare", 28, "AFT"),
	"giant_strength": _d("Giant Strength", "Large Tile", "Active Core attack bonus +4%", 5, "Common", 65, "CORE"),
	"stable_core": _d("Stable Core", "Large Tile", "128+ tile reduces enemy damage 8%", 3, "Rare", 28, "128"),
	"arcane_core": _d("Arcane Core", "Large Tile", "256+ tile grants charge +15%", 3, "Rare", 28, "256"),
	"break_charge": _d("Break Charge", "Utility", "Break max/current charges +1", 3, "Rare", 28, "BRK"),
	"small_start": _d("Small Start", "Utility", "New 4-tile chance -3%", 3, "Common", 65, "2+"),
	"battle_focus": _d("Battle Focus", "Utility", "No-merge move empowers next merge +20%", 3, "Common", 65, "FOC"),
	"stage_preparation": _d("Stage Preparation", "Utility", "New stage: heal 4 and gain 6 shield", 3, "Rare", 28, "PREP"),
	"quick_step": _d("Quick Step", "Speed", "Speed Combo window +0.15 sec", 4, "Common", 65, "SPD"),
	"momentum": _d("Momentum", "Speed", "Each Speed stack bonus +2%", 4, "Common", 65, "MOM"),
	"fever_charge": _d("Fever Charge", "Speed", "Fever gain +6%", 4, "Rare", 28, "HOT"),
	"fever_power": _d("Fever Power", "Speed", "Fever damage +8%", 3, "Rare", 28, "xF"),
	"long_fever": _d("Long Fever", "Speed", "Fever duration +1 move", 3, "Rare", 28, "+1"),
	"hot_start": _d("Hot Start", "Speed", "Each stage starts at Speed x2", 1, "Epic", 7, "x2"),
}


static func _d(name: String, category: String, description: String, max_level: int, rarity: String, weight: float, icon: String) -> Dictionary:
	return {"id": name.to_snake_case(), "name": name, "category": category, "description": description, "max_level": max_level, "rarity": rarity, "weight": weight, "icon": icon}


func get_random_choices(rng: RandomNumberGenerator, run_state: RunState, count: int = 3, unlocked_content: Array[String] = []) -> Array[String]:
	var pool: Array[String] = []
	for upgrade_id: String in ORDERED_IDS:
		if is_available(upgrade_id, run_state) and (not upgrade_id in ["quick_step", "momentum", "fever_charge", "fever_power", "long_fever", "hot_start"] or "speed_upgrade_pack" in unlocked_content): pool.append(upgrade_id)
	var result: Array[String] = []
	while result.size() < count and not pool.is_empty():
		var rarity_roll := rng.randf() * 100.0
		var wanted_rarity := "Common"
		if rarity_roll >= 93.0: wanted_rarity = "Epic"
		elif rarity_roll >= 65.0: wanted_rarity = "Rare"
		var rarity_pool: Array[String] = []
		for upgrade_id: String in pool:
			if str(DEFINITIONS[upgrade_id]["rarity"]) == wanted_rarity:
				rarity_pool.append(upgrade_id)
		if rarity_pool.is_empty(): rarity_pool = pool.duplicate()
		var selected := rarity_pool[rng.randi_range(0, rarity_pool.size() - 1)]
		result.append(selected)
		pool.erase(selected)
	return result


func generate_candidates(rng: RandomNumberGenerator, run_state: RunState, count: int = 3, unlocked_content: Array[String] = []) -> Array[String]:
	return get_random_choices(rng, run_state, count, unlocked_content)


func is_available(upgrade_id: String, run_state: RunState) -> bool:
	var data := get_upgrade_data(upgrade_id)
	return not data.is_empty() and run_state.get_upgrade_level(upgrade_id) < int(data["max_level"])


func get_upgrade_data(upgrade_id: String) -> Dictionary:
	return DEFINITIONS.get(upgrade_id, {})


func get_definition(upgrade_id: String) -> Dictionary:
	return get_upgrade_data(upgrade_id)


func apply_upgrade(upgrade_id: String, run_state: RunState) -> void:
	if is_available(upgrade_id, run_state): run_state.apply_upgrade(upgrade_id)


func get_change_text(upgrade_id: String, run_state: RunState) -> String:
	var data := get_upgrade_data(upgrade_id)
	var current := run_state.get_upgrade_level(upgrade_id)
	return "Lv.%d -> Lv.%d / Max %d" % [current, current + 1, int(data.get("max_level", 0))]
