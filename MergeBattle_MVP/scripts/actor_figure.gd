class_name ActorFigure
extends Control


var role: String = "PLAYER"
var variant: int = 0
var body_color: Color = Color("#5D79A8")
var detail_color: Color = Color("#EAF1FF")


func configure(new_role: String, new_variant: int, color: Color) -> void:
	role = new_role
	variant = new_variant
	body_color = color
	detail_color = color.lightened(0.55)
	queue_redraw()


func _draw() -> void:
	if role == "PLAYER":
		_draw_player()
		return

	match variant % 5:
		0:
			_draw_slime()
		1:
			_draw_goblin()
		2:
			_draw_golem()
		3:
			_draw_mage()
		_:
			_draw_dragon()


func _draw_player() -> void:
	draw_circle(Vector2(42.0, 19.0), 12.0, detail_color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(28.0, 32.0), Vector2(55.0, 32.0),
			Vector2(61.0, 65.0), Vector2(22.0, 65.0),
		]),
		body_color
	)
	draw_line(Vector2(29.0, 62.0), Vector2(24.0, 78.0), body_color, 7.0)
	draw_line(Vector2(53.0, 62.0), Vector2(59.0, 78.0), body_color, 7.0)
	draw_line(Vector2(54.0, 38.0), Vector2(78.0, 17.0), Color("#F6E7B0"), 5.0)
	draw_line(Vector2(71.0, 13.0), Vector2(82.0, 24.0), Color("#F6E7B0"), 3.0)
	draw_circle(Vector2(38.0, 17.0), 1.8, Color("#26344A"))
	draw_circle(Vector2(46.0, 17.0), 1.8, Color("#26344A"))


func _draw_slime() -> void:
	draw_circle(Vector2(46.0, 48.0), 30.0, body_color)
	draw_rect(Rect2(16.0, 48.0, 60.0, 25.0), body_color)
	draw_circle(Vector2(36.0, 45.0), 4.0, detail_color)
	draw_circle(Vector2(57.0, 45.0), 4.0, detail_color)
	draw_arc(Vector2(46.0, 56.0), 10.0, 0.25, 2.9, 16, detail_color, 2.5)


func _draw_goblin() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(16.0, 28.0), Vector2(31.0, 34.0), Vector2(61.0, 34.0),
			Vector2(78.0, 27.0), Vector2(66.0, 48.0), Vector2(62.0, 70.0),
			Vector2(28.0, 70.0), Vector2(25.0, 48.0),
		]), body_color
	)
	draw_circle(Vector2(37.0, 47.0), 3.0, detail_color)
	draw_circle(Vector2(55.0, 47.0), 3.0, detail_color)
	draw_line(Vector2(38.0, 60.0), Vector2(54.0, 60.0), detail_color, 3.0)


func _draw_golem() -> void:
	draw_rect(Rect2(24.0, 23.0, 44.0, 30.0), body_color)
	draw_rect(Rect2(18.0, 51.0, 56.0, 29.0), body_color.darkened(0.12))
	draw_rect(Rect2(8.0, 48.0, 13.0, 25.0), body_color)
	draw_rect(Rect2(71.0, 48.0, 13.0, 25.0), body_color)
	draw_rect(Rect2(33.0, 34.0, 6.0, 5.0), detail_color)
	draw_rect(Rect2(54.0, 34.0, 6.0, 5.0), detail_color)


func _draw_mage() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(46.0, 8.0), Vector2(20.0, 43.0), Vector2(73.0, 43.0),
		]), body_color.darkened(0.18)
	)
	draw_circle(Vector2(46.0, 43.0), 15.0, detail_color)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(29.0, 52.0), Vector2(63.0, 52.0), Vector2(75.0, 80.0),
			Vector2(17.0, 80.0),
		]), body_color
	)
	draw_circle(Vector2(41.0, 43.0), 2.0, Color("#452F66"))
	draw_circle(Vector2(52.0, 43.0), 2.0, Color("#452F66"))


func _draw_dragon() -> void:
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(20.0, 49.0), Vector2(4.0, 22.0), Vector2(35.0, 38.0),
			Vector2(46.0, 17.0), Vector2(56.0, 38.0), Vector2(88.0, 22.0),
			Vector2(72.0, 51.0), Vector2(64.0, 77.0), Vector2(28.0, 77.0),
		]), body_color
	)
	draw_colored_polygon(
		PackedVector2Array([
			Vector2(35.0, 38.0), Vector2(46.0, 24.0), Vector2(58.0, 38.0),
			Vector2(62.0, 61.0), Vector2(31.0, 61.0),
		]), body_color.lightened(0.12)
	)
	draw_circle(Vector2(40.0, 44.0), 2.5, detail_color)
	draw_circle(Vector2(53.0, 44.0), 2.5, detail_color)
