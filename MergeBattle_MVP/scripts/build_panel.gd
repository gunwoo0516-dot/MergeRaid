class_name BuildPanel
extends ScrollContainer

var details_label: Label


func _ready() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_ensure_label()


func _ensure_label() -> void:
	if details_label != null:
		return
	details_label = Label.new()
	details_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details_label.add_theme_font_size_override("font_size", 18)
	add_child(details_label)


func set_summary(summary: String) -> void:
	_ensure_label()
	details_label.text = summary
