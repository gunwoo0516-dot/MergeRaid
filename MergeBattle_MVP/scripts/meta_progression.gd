class_name MetaProgression
extends RefCounted

const PASSIVES := {
	"steady_start": {"name":"Steady Start", "cost":0, "effect":"Start each run with 10 Shield"},
	"swift_hands": {"name":"Swift Hands", "cost":8, "effect":"Speed window +0.20 sec"},
	"core_keeper": {"name":"Core Keeper", "cost":10, "effect":"Large Tile Core +5%"},
	"ultimate_seed": {"name":"Ultimate Seed", "cost":12, "effect":"Start with 15% Ultimate"},
	"breaker": {"name":"Breaker", "cost":12, "effect":"Start with +1 Break charge"},
}
const PACKS := {
	"fire_upgrade_pack":{"name":"Fire Upgrade Pack", "cost":15},
	"speed_upgrade_pack":{"name":"Speed Upgrade Pack", "cost":15},
	"guardian_upgrade_pack":{"name":"Guardian Upgrade Pack", "cost":15},
}
const PREVIEWS := ["Archer", "Mage", "Greatsword", "Bow", "Staff"]

func purchase(save: SaveManager, content_id: String) -> bool:
	if save.is_unlocked(content_id): return false
	var data: Dictionary = PASSIVES.get(content_id, PACKS.get(content_id, {}))
	if data.is_empty() or not save.spend_souls(int(data["cost"])): return false
	save.unlock_content(content_id)
	return true
