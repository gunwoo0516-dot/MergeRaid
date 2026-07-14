class_name EnemyDatabase
extends RefCounted

const ENEMIES: Array[Dictionary] = [
	{"id":"slime","display_name":"SLIME","base_hp":62,"hp_growth":14,"base_damage":7,"damage_growth":2,"attack_interval":3,"behavior_id":"none","visual_type":"slime","color":Color("#65A867"),"description":"Attacks every 3 moves"},
	{"id":"goblin","display_name":"GOBLIN","base_hp":78,"hp_growth":15,"base_damage":5,"damage_growth":1,"attack_interval":2,"behavior_id":"rapid","visual_type":"goblin","color":Color("#8BAE45"),"description":"Fast, but weak"},
	{"id":"golem","display_name":"STONE GOLEM","base_hp":112,"hp_growth":18,"base_damage":13,"damage_growth":3,"attack_interval":4,"behavior_id":"heavy","visual_type":"golem","color":Color("#8C8178"),"description":"Slow, heavy attack"},
	{"id":"mage","display_name":"DARK MAGE","base_hp":102,"hp_growth":18,"base_damage":8,"damage_growth":2,"attack_interval":3,"behavior_id":"drain_ultimate","visual_type":"mage","color":Color("#7453A6"),"description":"Drains Ultimate gauge"},
	{"id":"dragon","display_name":"DRAGON","base_hp":145,"hp_growth":22,"base_damage":12,"damage_growth":3,"attack_interval":3,"behavior_id":"break_momentum","visual_type":"dragon","color":Color("#B64A3B"),"description":"Breaks your momentum"},
]

static func get_for_stage(stage: int) -> Dictionary:
	var data: Dictionary = ENEMIES[(stage - 1) % ENEMIES.size()].duplicate(true)
	var cycle := (stage - 1) / ENEMIES.size()
	data["max_hp"] = int(data["base_hp"]) + (stage - 1) * int(data["hp_growth"]) + cycle * 12
	data["damage"] = int(data["base_damage"]) + (stage - 1) * int(data["damage_growth"])
	if str(data["id"]) == "dragon": data["attack_interval"] = 3 if cycle % 2 == 0 else 2
	return data
