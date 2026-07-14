class_name BattleActorView
extends PanelContainer


const ActorFigureScript = preload("res://scripts/actor_figure.gd")

var figure: ActorFigure
var role_label: Label
var actor_role: String = "PLAYER"
var home_position: Vector2 = Vector2.ZERO
var figure_home_position: Vector2 = Vector2.ZERO
var motion_tween: Tween
var hit_tween: Tween
var idle_tween: Tween


func setup(display_name: String, role: String, color: Color, stage: int = 1) -> void:
	actor_role = role
	custom_minimum_size = Vector2(112.0, 112.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", _create_style(color.darkened(0.3), 16))

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	figure = ActorFigureScript.new()
	figure.custom_minimum_size = Vector2(92.0, 82.0)
	figure.mouse_filter = Control.MOUSE_FILTER_IGNORE
	figure.configure(role, stage - 1, color)
	box.add_child(figure)

	role_label = Label.new()
	role_label.text = display_name
	role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	role_label.add_theme_font_size_override("font_size", 14)
	role_label.add_theme_color_override("font_color", Color.WHITE)
	role_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(role_label)
	call_deferred("_capture_home_and_idle")


func configure_actor(display_name: String, stage: int, color: Color) -> void:
	_stop_all_tweens()
	role_label.text = display_name
	figure.configure(actor_role, stage - 1, color)
	add_theme_stylebox_override("panel", _create_style(color.darkened(0.3), 16))
	_reset_visual_state()
	play_spawn()


func set_actor_name(display_name: String) -> void:
	_stop_all_tweens()
	role_label.text = display_name
	_reset_visual_state()
	play_idle()


func play_idle() -> void:
	_stop_idle()
	figure.position = figure_home_position
	idle_tween = create_tween().set_loops()
	idle_tween.set_trans(Tween.TRANS_SINE)
	idle_tween.set_ease(Tween.EASE_IN_OUT)
	idle_tween.tween_property(figure, "position:y", figure_home_position.y - 2.5, 0.65)
	idle_tween.tween_property(figure, "position:y", figure_home_position.y + 1.5, 0.65)


func play_attack(target_position: Vector2, power: int) -> void:
	_stop_motion()
	_stop_idle()
	position = home_position
	var center: Vector2 = global_position + size * 0.5
	var direction: Vector2 = center.direction_to(target_position)
	var strength: float = clampf(float(power) / 64.0, 0.0, 1.0)
	motion_tween = create_tween()
	motion_tween.set_trans(Tween.TRANS_QUAD)
	motion_tween.set_ease(Tween.EASE_OUT)
	motion_tween.tween_property(
		self, "position", home_position + direction * (18.0 + strength * 12.0), 0.055
	)
	motion_tween.tween_property(self, "position", home_position, 0.055)
	motion_tween.finished.connect(play_idle)


func play_hit(damage: int, power: int = 1) -> void:
	_stop_hit()
	_stop_motion()
	_stop_idle()
	position = home_position
	modulate = Color(1.0, 0.42, 0.42, 1.0)
	var shake: float = clampf(4.0 + float(maxi(damage, power)) * 0.025, 4.0, 10.0)
	hit_tween = create_tween()
	hit_tween.set_parallel(true)
	hit_tween.tween_property(self, "modulate", Color.WHITE, 0.1)
	hit_tween.tween_method(_apply_hit_shake.bind(shake), 0.0, 1.0, 0.1)
	hit_tween.finished.connect(play_idle)


func play_death() -> void:
	_stop_all_tweens()
	pivot_offset = size * 0.5
	motion_tween = create_tween()
	motion_tween.set_parallel(true)
	motion_tween.tween_property(self, "scale", Vector2(0.72, 0.72), 0.13)
	motion_tween.tween_property(self, "modulate:a", 0.0, 0.13)


func play_spawn() -> void:
	_stop_all_tweens()
	pivot_offset = size * 0.5
	position = home_position
	modulate = Color.WHITE
	scale = Vector2(0.72, 0.72)
	motion_tween = create_tween()
	motion_tween.tween_property(self, "scale", Vector2.ONE, 0.14).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	motion_tween.finished.connect(play_idle)


func play_ultimate(target_position: Vector2, power: int) -> void:
	_stop_motion()
	_stop_idle()
	position = home_position
	var center: Vector2 = global_position + size * 0.5
	var direction: Vector2 = center.direction_to(target_position)
	pivot_offset = size * 0.5
	motion_tween = create_tween()
	motion_tween.set_parallel(true)
	motion_tween.tween_property(self, "scale", Vector2(1.18, 1.18), 0.1)
	motion_tween.tween_property(self, "position", home_position + direction * 30.0, 0.1)
	motion_tween.chain().tween_property(self, "scale", Vector2.ONE, 0.08)
	motion_tween.parallel().tween_property(self, "position", home_position, 0.08)
	motion_tween.finished.connect(play_idle)


func _capture_home_and_idle() -> void:
	home_position = position
	figure_home_position = figure.position
	play_idle()


func _apply_hit_shake(progress: float, shake: float) -> void:
	var decay: float = 1.0 - progress
	position.x = home_position.x + sin(progress * TAU * 3.0) * shake * decay


func _reset_visual_state() -> void:
	position = home_position
	figure.position = figure_home_position
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0


func _stop_all_tweens() -> void:
	_stop_motion()
	_stop_hit()
	_stop_idle()


func _stop_motion() -> void:
	if motion_tween != null and motion_tween.is_valid():
		motion_tween.kill()
	motion_tween = null


func _stop_hit() -> void:
	if hit_tween != null and hit_tween.is_valid():
		hit_tween.kill()
	hit_tween = null


func _stop_idle() -> void:
	if idle_tween != null and idle_tween.is_valid():
		idle_tween.kill()
	idle_tween = null


func _create_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style
