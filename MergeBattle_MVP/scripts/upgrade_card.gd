class_name UpgradeCard
extends Button

signal upgrade_chosen(upgrade_id: String)

var upgrade_id := ""
var _chosen := false


func setup(data: Dictionary, current_level: int) -> void:
	upgrade_id = str(data["id"])
	text = "%s  [%s]\n%s\n%s\n\n%s\nLv.%d -> Lv.%d / Max %d" % [
		str(data["icon"]), str(data["rarity"]), str(data["name"]),
		str(data["category"]), str(data["description"]), current_level,
		current_level + 1, int(data["max_level"]),
	]
	custom_minimum_size = Vector2(0.0, 188.0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clip_text = true
	add_theme_font_size_override("font_size", 17)
	var color := Color("#C99B4A")
	if str(data["rarity"]) == "Rare": color = Color("#5686B8")
	elif str(data["rarity"]) == "Epic": color = Color("#9A62C7")
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#F7F0E5")
	style.border_color = color
	style.set_border_width_all(4)
	style.set_corner_radius_all(14)
	add_theme_stylebox_override("normal", style)
	pressed.connect(_choose_once)


func _choose_once() -> void:
	if _chosen: return
	_chosen = true
	disabled = true
	upgrade_chosen.emit(upgrade_id)
