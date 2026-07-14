extends Control


const BoardLogicScript = preload("res://scripts/board_logic.gd")
const BattleActorViewScript = preload("res://scripts/battle_actor_view.gd")
const RunStateScript = preload("res://scripts/run_state.gd")
const UpgradeSystemScript = preload("res://scripts/upgrade_system.gd")
const SaveManagerScript = preload("res://scripts/save_manager.gd")

const BOARD_SIZE: int = 4
const TILE_SIZE := Vector2(132.0, 132.0)
const SWIPE_MIN_DISTANCE: float = 50.0
const TILE_MOVE_DURATION: float = 0.1
const MERGE_POP_DURATION: float = 0.08
const SPAWN_DURATION: float = 0.08
const DAMAGE_TEXT_DURATION: float = 0.34

const ULTIMATE_MIN_TILE: int = 64
const BASE_ENEMY_HP: int = 72
const ENEMY_HP_GROWTH: int = 42
const BASE_ENEMY_DAMAGE: int = 9
const ENEMY_DAMAGE_GROWTH: int = 2

var logic = BoardLogicScript.new()
var rng := RandomNumberGenerator.new()
var run_state: RunState = RunStateScript.new()
var upgrade_system: UpgradeSystem = UpgradeSystemScript.new()
var save_manager: SaveManager = SaveManagerScript.new()

var tile_panels: Array[PanelContainer] = []
var tile_labels: Array[Label] = []

var score: int = 0
var stage: int = 1
var turn_count: int = 0

var player_hp: int = RunState.BASE_PLAYER_HP
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var enemy_generation: int = 0
var pending_player_attacks: int = 0
var stage_clear_pending: bool = false
var run_recorded: bool = false
var has_active_run: bool = false

var game_is_over: bool = false
var input_enabled: bool = true
var is_animating: bool = false

var touch_start := Vector2.ZERO
var touch_current := Vector2.ZERO
var touch_active: bool = false

var score_label: Label
var stage_label: Label
var meta_label: Label
var player_hp_label: Label
var player_hp_bar: ProgressBar
var enemy_name_label: Label
var enemy_hp_label: Label
var enemy_hp_bar: ProgressBar
var turn_label: Label
var status_label: Label
var damage_label: Label
var ultimate_button: Button
var restart_button: Button
var enemy_panel: PanelContainer
var player_hp_panel: PanelContainer
var player_actor: BattleActorView
var enemy_actor: BattleActorView
var effects_layer: Control
var screen_flash: ColorRect
var turn_indicators: Array[PanelContainer] = []
var game_over_overlay: ColorRect
var game_over_reason_label: Label
var upgrade_overlay: ColorRect
var upgrade_cards_row: HBoxContainer
var build_overlay: ColorRect
var build_details_label: Label
var build_button: Button


func _ready() -> void:
	rng.randomize()
	save_manager.load_save()
	_build_screen()
	_start_new_game()


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		_handle_key_input(event as InputEventKey)
		return

	if not input_enabled or game_is_over:
		return

	if event is InputEventScreenTouch:
		var touch_event := event as InputEventScreenTouch

		if touch_event.index != 0:
			return

		if touch_event.pressed:
			touch_start = touch_event.position
			touch_current = touch_event.position
			touch_active = true
		else:
			if touch_active:
				touch_current = touch_event.position
				_finish_swipe()

			touch_active = false

	elif event is InputEventScreenDrag:
		var drag_event := event as InputEventScreenDrag

		if drag_event.index == 0 and touch_active:
			touch_current = drag_event.position

	elif event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton

		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_button.pressed:
			touch_start = mouse_button.position
			touch_current = mouse_button.position
			touch_active = true
		else:
			if touch_active:
				touch_current = mouse_button.position
				_finish_swipe()

			touch_active = false

	elif event is InputEventMouseMotion:
		var mouse_motion := event as InputEventMouseMotion

		if touch_active:
			touch_current = mouse_motion.position


func _handle_key_input(key_event: InputEventKey) -> void:
	if not key_event.pressed or key_event.echo:
		return

	if OS.is_debug_build() and _handle_debug_key(key_event.keycode):
		return

	if key_event.keycode == KEY_R:
		if input_enabled or game_is_over:
			_start_new_game()
		return

	if game_is_over or not input_enabled:
		return

	match key_event.keycode:
		KEY_LEFT, KEY_A:
			_try_move(BoardLogicScript.Direction.LEFT)
		KEY_RIGHT, KEY_D:
			_try_move(BoardLogicScript.Direction.RIGHT)
		KEY_UP, KEY_W:
			_try_move(BoardLogicScript.Direction.UP)
		KEY_DOWN, KEY_S:
			_try_move(BoardLogicScript.Direction.DOWN)
		KEY_U:
			_use_ultimate()


func _handle_debug_key(keycode: Key) -> bool:
	match keycode:
		KEY_F1:
			if is_animating:
				return true
			enemy_hp = 1
			_refresh_enemy_ui()
			status_label.text = "DEBUG: Enemy HP set to 1"
			return true
		KEY_F2:
			if is_animating:
				return true
			var index: int = logic.cells.find(0)
			if index >= 0:
				logic.cells[index] = 64
				_refresh_board()
			status_label.text = "DEBUG: Added a 64 tile"
			return true
		KEY_F3:
			save_manager.add_soul(5)
			_refresh_meta_ui()
			status_label.text = "DEBUG: Added 5 Souls"
			return true
		KEY_F4:
			if not is_animating and not stage_clear_pending and not game_is_over:
				stage_clear_pending = true
				_show_upgrade_selection()
			return true
		KEY_F8:
			save_manager.reset_save_for_debug()
			run_state.permanent_attack_multiplier = 1.0
			_refresh_meta_ui()
			status_label.text = "DEBUG: Save reset"
			return true
	return false


func _build_screen() -> void:
	var background := ColorRect.new()
	background.name = "Background"
	background.color = Color("#F7F3EA")
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var content := VBoxContainer.new()
	content.name = "Content"
	content.custom_minimum_size = Vector2(640.0, 0.0)
	content.add_theme_constant_override("separation", 14)
	center.add_child(content)

	_build_header(content)
	_build_player_row(content)
	_build_enemy_panel(content)
	_build_board(content)
	_build_action_area(content)
	_build_effects_layer()
	_build_upgrade_overlay()
	_build_build_overlay()
	_build_game_over_overlay()


func _build_header(parent: VBoxContainer) -> void:
	var header := HBoxContainer.new()
	header.name = "Header"
	header.add_theme_constant_override("separation", 12)
	parent.add_child(header)

	var title := Label.new()
	title.text = "MERGE BATTLE"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 46)
	title.add_theme_color_override("font_color", Color("#5F574F"))
	header.add_child(title)

	var info_box := VBoxContainer.new()
	info_box.alignment = BoxContainer.ALIGNMENT_CENTER
	header.add_child(info_box)

	stage_label = Label.new()
	stage_label.text = "STAGE 1"
	stage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	stage_label.add_theme_font_size_override("font_size", 24)
	stage_label.add_theme_color_override("font_color", Color("#8A5A44"))
	info_box.add_child(stage_label)

	meta_label = Label.new()
	meta_label.text = "Souls 0  |  Best 1  |  Power +0%"
	meta_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	meta_label.add_theme_font_size_override("font_size", 13)
	meta_label.add_theme_color_override("font_color", Color("#756A61"))
	info_box.add_child(meta_label)


func _build_player_row(parent: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	row.name = "PlayerRow"
	row.custom_minimum_size = Vector2(0.0, 90.0)
	row.add_theme_constant_override("separation", 12)
	parent.add_child(row)

	player_actor = BattleActorViewScript.new()
	player_actor.name = "PlayerActor"
	player_actor.setup("PLAYER", "PLAYER", Color("#5D79A8"), 1)
	row.add_child(player_actor)

	player_hp_panel = PanelContainer.new()
	player_hp_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	player_hp_panel.add_theme_stylebox_override(
		"panel",
		_create_box_style(Color("#E7DED2"), 12)
	)
	row.add_child(player_hp_panel)

	var hp_margin := _create_margin_container(14, 10, 14, 10)
	player_hp_panel.add_child(hp_margin)

	var hp_box := VBoxContainer.new()
	hp_box.add_theme_constant_override("separation", 4)
	hp_margin.add_child(hp_box)

	var hp_title_row := HBoxContainer.new()
	hp_box.add_child(hp_title_row)

	var hp_title := Label.new()
	hp_title.text = "PLAYER HP"
	hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_title.add_theme_font_size_override("font_size", 18)
	hp_title.add_theme_color_override("font_color", Color("#5F574F"))
	hp_title_row.add_child(hp_title)

	player_hp_label = Label.new()
	player_hp_label.text = "100 / 100"
	player_hp_label.add_theme_font_size_override("font_size", 18)
	player_hp_label.add_theme_color_override("font_color", Color("#5F574F"))
	hp_title_row.add_child(player_hp_label)

	player_hp_bar = ProgressBar.new()
	player_hp_bar.custom_minimum_size = Vector2(0.0, 25.0)
	player_hp_bar.min_value = 0
	player_hp_bar.max_value = RunState.BASE_PLAYER_HP
	player_hp_bar.value = RunState.BASE_PLAYER_HP
	player_hp_bar.show_percentage = false
	player_hp_bar.add_theme_stylebox_override(
		"background",
		_create_box_style(Color("#CFC3B6"), 8)
	)
	player_hp_bar.add_theme_stylebox_override(
		"fill",
		_create_box_style(Color("#70A36B"), 8)
	)
	hp_box.add_child(player_hp_bar)

	var score_panel := PanelContainer.new()
	score_panel.custom_minimum_size = Vector2(185.0, 0.0)
	score_panel.add_theme_stylebox_override(
		"panel",
		_create_box_style(Color("#A9917D"), 12)
	)
	row.add_child(score_panel)

	var score_box := VBoxContainer.new()
	score_box.alignment = BoxContainer.ALIGNMENT_CENTER
	score_panel.add_child(score_box)

	var score_title := Label.new()
	score_title.text = "SCORE"
	score_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_title.add_theme_font_size_override("font_size", 18)
	score_title.add_theme_color_override("font_color", Color("#F2EAE1"))
	score_box.add_child(score_title)

	score_label = Label.new()
	score_label.text = "0"
	score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	score_label.add_theme_font_size_override("font_size", 32)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_box.add_child(score_label)


func _build_enemy_panel(parent: VBoxContainer) -> void:
	enemy_panel = PanelContainer.new()
	enemy_panel.name = "EnemyPanel"
	enemy_panel.custom_minimum_size = Vector2(0.0, 140.0)
	enemy_panel.add_theme_stylebox_override(
		"panel",
		_create_box_style(Color("#E9C9BD"), 16)
	)
	parent.add_child(enemy_panel)

	var margin := _create_margin_container(18, 12, 18, 12)
	enemy_panel.add_child(margin)

	var enemy_content := HBoxContainer.new()
	enemy_content.add_theme_constant_override("separation", 14)
	margin.add_child(enemy_content)

	var enemy_box := VBoxContainer.new()
	enemy_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_box.add_theme_constant_override("separation", 5)
	enemy_content.add_child(enemy_box)

	var enemy_title_row := HBoxContainer.new()
	enemy_box.add_child(enemy_title_row)

	enemy_name_label = Label.new()
	enemy_name_label.text = "SLIME"
	enemy_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_name_label.add_theme_font_size_override("font_size", 28)
	enemy_name_label.add_theme_color_override("font_color", Color("#713F39"))
	enemy_title_row.add_child(enemy_name_label)

	turn_label = Label.new()
	turn_label.text = "ATTACK IN 3"
	turn_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	turn_label.add_theme_font_size_override("font_size", 18)
	turn_label.add_theme_color_override("font_color", Color("#713F39"))
	enemy_title_row.add_child(turn_label)

	var enemy_hp_row := HBoxContainer.new()
	enemy_box.add_child(enemy_hp_row)

	var enemy_hp_title := Label.new()
	enemy_hp_title.text = "ENEMY HP"
	enemy_hp_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	enemy_hp_title.add_theme_font_size_override("font_size", 17)
	enemy_hp_title.add_theme_color_override("font_color", Color("#713F39"))
	enemy_hp_row.add_child(enemy_hp_title)

	enemy_hp_label = Label.new()
	enemy_hp_label.text = "0 / 0"
	enemy_hp_label.add_theme_font_size_override("font_size", 17)
	enemy_hp_label.add_theme_color_override("font_color", Color("#713F39"))
	enemy_hp_row.add_child(enemy_hp_label)

	enemy_hp_bar = ProgressBar.new()
	enemy_hp_bar.custom_minimum_size = Vector2(0.0, 26.0)
	enemy_hp_bar.min_value = 0
	enemy_hp_bar.max_value = 100
	enemy_hp_bar.value = 100
	enemy_hp_bar.show_percentage = false
	enemy_hp_bar.add_theme_stylebox_override(
		"background",
		_create_box_style(Color("#C89E92"), 8)
	)
	enemy_hp_bar.add_theme_stylebox_override(
		"fill",
		_create_box_style(Color("#C6534D"), 8)
	)
	enemy_box.add_child(enemy_hp_bar)

	damage_label = Label.new()
	damage_label.text = ""
	damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	damage_label.add_theme_font_size_override("font_size", 21)
	damage_label.add_theme_color_override("font_color", Color("#9E2F2A"))
	enemy_box.add_child(damage_label)
	damage_label.visible = false

	enemy_actor = BattleActorViewScript.new()
	enemy_actor.name = "EnemyActor"
	enemy_actor.setup("SLIME", "ENEMY", Color("#65A867"), 1)
	enemy_content.add_child(enemy_actor)


func _build_board(parent: VBoxContainer) -> void:
	var board_panel := PanelContainer.new()
	board_panel.name = "BoardPanel"
	board_panel.custom_minimum_size = Vector2(604.0, 604.0)
	board_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	board_panel.add_theme_stylebox_override(
		"panel",
		_create_box_style(Color("#A9917D"), 16)
	)
	parent.add_child(board_panel)

	var board_margin := _create_margin_container(20, 20, 20, 20)
	board_panel.add_child(board_margin)

	var board_grid := GridContainer.new()
	board_grid.name = "BoardGrid"
	board_grid.columns = BOARD_SIZE
	board_grid.add_theme_constant_override("h_separation", 12)
	board_grid.add_theme_constant_override("v_separation", 12)
	board_margin.add_child(board_grid)

	for index in range(BOARD_SIZE * BOARD_SIZE):
		var tile := PanelContainer.new()
		tile.name = "Tile%d" % index
		tile.custom_minimum_size = TILE_SIZE
		tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board_grid.add_child(tile)

		var number_label := Label.new()
		number_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		number_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		number_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tile.add_child(number_label)

		tile_panels.append(tile)
		tile_labels.append(number_label)


func _build_action_area(parent: VBoxContainer) -> void:
	var action_row := HBoxContainer.new()
	action_row.custom_minimum_size = Vector2(0.0, 72.0)
	action_row.add_theme_constant_override("separation", 12)
	parent.add_child(action_row)

	ultimate_button = Button.new()
	ultimate_button.name = "UltimateButton"
	ultimate_button.text = "ULTIMATE  |  Consume 64+"
	ultimate_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ultimate_button.add_theme_font_size_override("font_size", 23)
	ultimate_button.add_theme_stylebox_override(
		"normal",
		_create_box_style(Color("#7659A8"), 12)
	)
	ultimate_button.add_theme_stylebox_override(
		"hover",
		_create_box_style(Color("#8567B8"), 12)
	)
	ultimate_button.add_theme_stylebox_override(
		"pressed",
		_create_box_style(Color("#62478F"), 12)
	)
	ultimate_button.add_theme_color_override("font_color", Color.WHITE)
	ultimate_button.pressed.connect(_use_ultimate)
	action_row.add_child(ultimate_button)

	build_button = Button.new()
	build_button.text = "BUILD"
	build_button.custom_minimum_size = Vector2(105.0, 0.0)
	build_button.add_theme_font_size_override("font_size", 18)
	build_button.pressed.connect(_show_build_overlay)
	action_row.add_child(build_button)

	restart_button = Button.new()
	restart_button.text = "RESTART"
	restart_button.custom_minimum_size = Vector2(120.0, 0.0)
	restart_button.add_theme_font_size_override("font_size", 21)
	restart_button.pressed.connect(_start_new_game)
	action_row.add_child(restart_button)

	status_label = Label.new()
	status_label.text = "Arrow keys / WASD / Swipe"
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.add_theme_font_size_override("font_size", 20)
	status_label.add_theme_color_override("font_color", Color("#5F574F"))
	parent.add_child(status_label)

	var indicator_row := HBoxContainer.new()
	indicator_row.alignment = BoxContainer.ALIGNMENT_CENTER
	indicator_row.add_theme_constant_override("separation", 8)
	parent.add_child(indicator_row)

	var indicator_text := Label.new()
	indicator_text.text = "Enemy attack"
	indicator_text.add_theme_font_size_override("font_size", 16)
	indicator_text.add_theme_color_override("font_color", Color("#713F39"))
	indicator_row.add_child(indicator_text)

	for index in range(5):
		var indicator := PanelContainer.new()
		indicator.custom_minimum_size = Vector2(28.0, 14.0)
		indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
		indicator_row.add_child(indicator)
		turn_indicators.append(indicator)


func _build_effects_layer() -> void:
	effects_layer = Control.new()
	effects_layer.name = "EffectsLayer"
	effects_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(effects_layer)
	effects_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	screen_flash = ColorRect.new()
	screen_flash.color = Color(1.0, 0.87, 0.35, 0.0)
	screen_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	effects_layer.add_child(screen_flash)
	screen_flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _build_upgrade_overlay() -> void:
	upgrade_overlay = ColorRect.new()
	upgrade_overlay.name = "UpgradeOverlay"
	upgrade_overlay.color = Color(0.08, 0.07, 0.09, 0.88)
	upgrade_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	upgrade_overlay.visible = false
	add_child(upgrade_overlay)
	upgrade_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	upgrade_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(660.0, 0.0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
	var title := Label.new()
	title.text = "STAGE CLEAR — CHOOSE AN UPGRADE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color("#FFF0B8"))
	box.add_child(title)
	upgrade_cards_row = HBoxContainer.new()
	upgrade_cards_row.add_theme_constant_override("separation", 12)
	box.add_child(upgrade_cards_row)


func _build_build_overlay() -> void:
	build_overlay = ColorRect.new()
	build_overlay.name = "BuildOverlay"
	build_overlay.color = Color(0.08, 0.07, 0.09, 0.78)
	build_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	build_overlay.visible = false
	add_child(build_overlay)
	build_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	build_overlay.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(500.0, 500.0)
	panel.add_theme_stylebox_override("panel", _create_box_style(Color("#F7F3EA"), 18))
	center.add_child(panel)
	var margin := _create_margin_container(28, 24, 28, 24)
	panel.add_child(margin)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	margin.add_child(box)
	var title := Label.new()
	title.text = "CURRENT BUILD"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	box.add_child(title)
	build_details_label = Label.new()
	build_details_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	build_details_label.add_theme_font_size_override("font_size", 20)
	box.add_child(build_details_label)
	var close_button := Button.new()
	close_button.text = "CLOSE"
	close_button.custom_minimum_size = Vector2(0.0, 58.0)
	close_button.pressed.connect(_hide_build_overlay)
	box.add_child(close_button)


func _build_game_over_overlay() -> void:
	game_over_overlay = ColorRect.new()
	game_over_overlay.name = "GameOverOverlay"
	game_over_overlay.color = Color(0.12, 0.10, 0.09, 0.82)
	game_over_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	game_over_overlay.visible = false
	add_child(game_over_overlay)
	game_over_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var overlay_center := CenterContainer.new()
	game_over_overlay.add_child(overlay_center)
	overlay_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dialog := PanelContainer.new()
	dialog.custom_minimum_size = Vector2(510.0, 320.0)
	dialog.add_theme_stylebox_override(
		"panel",
		_create_box_style(Color("#F7F3EA"), 20)
	)
	overlay_center.add_child(dialog)

	var margin := _create_margin_container(34, 28, 34, 28)
	dialog.add_child(margin)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 16)
	margin.add_child(box)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color("#A4413D"))
	box.add_child(title)

	game_over_reason_label = Label.new()
	game_over_reason_label.text = ""
	game_over_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game_over_reason_label.add_theme_font_size_override("font_size", 23)
	game_over_reason_label.add_theme_color_override("font_color", Color("#5F574F"))
	box.add_child(game_over_reason_label)

	var retry_button := Button.new()
	retry_button.text = "PLAY AGAIN"
	retry_button.custom_minimum_size = Vector2(0.0, 70.0)
	retry_button.add_theme_font_size_override("font_size", 25)
	retry_button.pressed.connect(_start_new_game)
	box.add_child(retry_button)


func _start_new_game() -> void:
	if is_animating:
		return
	if has_active_run and not run_recorded:
		save_manager.record_run(stage)

	logic.reset()
	run_state.reset_for_new_run(save_manager.get_permanent_attack_multiplier())

	score = 0
	stage = 1
	turn_count = 0
	player_hp = run_state.get_player_max_hp()
	game_is_over = false
	input_enabled = true
	is_animating = false
	touch_active = false
	stage_clear_pending = false
	pending_player_attacks = 0
	run_recorded = false
	has_active_run = true

	game_over_overlay.visible = false
	upgrade_overlay.visible = false
	build_overlay.visible = false
	restart_button.disabled = false

	_set_enemy_for_stage()
	logic.spawn_random_tile(rng)
	logic.spawn_random_tile(rng)

	status_label.text = "Arrow keys / WASD / Swipe"
	damage_label.text = ""
	player_actor.set_actor_name("PLAYER")
	player_hp_panel.modulate = Color.WHITE

	_refresh_all_ui()


func _try_move(direction: int) -> void:
	if game_is_over or not input_enabled:
		return

	var result: Dictionary = logic.move(direction)

	if not bool(result["changed"]):
		status_label.text = "No tile moved"
		_check_board_game_over()
		return

	_set_input_locked(true)
	var merged_values: Array = result["merged_values"]
	var move_events: Array = result["move_events"]
	var merge_score: int = int(result["merge_score"])
	var enemy_attack_due: bool

	score += merge_score
	turn_count += 1
	enemy_attack_due = (
		turn_count % run_state.get_enemy_attack_interval() == 0
	)
	_refresh_score_and_turn()
	if enemy_attack_due:
		_set_attack_indicator_alert()
	await _animate_tile_moves(move_events)
	_refresh_board()

	if not merged_values.is_empty():
		await _animate_merge_pops(move_events)

	var spawn_info: Dictionary = logic.spawn_random_tile_info(rng)
	_refresh_board()
	if not spawn_info.is_empty():
		await _animate_spawn_tile(int(spawn_info["index"]))

	_refresh_all_ui()
	_set_input_locked(false)

	if not merged_values.is_empty():
		var attack: Dictionary = _calculate_merge_attack(merged_values)
		var damage: int = int(attack["damage"])
		var combo_bonus: int = int(attack["final_combo_bonus"])
		var largest_merge: int = int(attack["largest_merge"])

		if combo_bonus > 0:
			status_label.text = (
				"%d merges! Combo +%d damage"
				% [merged_values.size(), combo_bonus]
			)
		else:
			status_label.text = "Merge attack: %d damage" % damage

		_start_player_attack(
			damage,
			largest_merge,
			merged_values.size(),
			false,
			enemy_attack_due
		)
	else:
		status_label.text = "Moved"
		if enemy_attack_due:
			_start_enemy_attack(enemy_generation)
		_check_board_game_over()


func _calculate_merge_attack(merged_values: Array) -> Dictionary:
	var base_damage: int = 0
	var largest_merge: int = 0

	for raw_value in merged_values:
		var value := int(raw_value)
		base_damage += value
		largest_merge = maxi(largest_merge, value)

	var extra_merge_count: int = maxi(0, merged_values.size() - 1)
	var base_combo_bonus: int = roundi(
		float(base_damage) * float(extra_merge_count) * 0.25
	)
	var final_combo_bonus: int = run_state.get_final_combo_bonus(base_combo_bonus)
	var damage: int = run_state.get_final_attack_damage(
		base_damage, base_combo_bonus
	)

	return {
		"damage": damage,
		"base_damage": base_damage,
		"combo_bonus": base_combo_bonus,
		"final_combo_bonus": final_combo_bonus,
		"largest_merge": largest_merge,
	}


func _damage_enemy(damage: int) -> void:
	enemy_hp = maxi(0, enemy_hp - damage)
	_refresh_enemy_ui()


func _start_enemy_attack(generation: int) -> void:
	if game_is_over or stage_clear_pending or generation != enemy_generation:
		return
	var damage: int = BASE_ENEMY_DAMAGE + (stage - 1) * ENEMY_DAMAGE_GROWTH
	_set_attack_indicator_alert()
	enemy_actor.play_attack(_actor_center(player_actor), damage)
	var timer := get_tree().create_timer(0.1)
	timer.timeout.connect(_resolve_enemy_hit.bind(damage, generation))


func _resolve_enemy_hit(damage: int, generation: int) -> void:
	if game_is_over or stage_clear_pending or generation != enemy_generation:
		return
	player_hp = maxi(0, player_hp - damage)
	status_label.text = "Enemy attack! -%d HP" % damage
	_refresh_player_ui()
	_show_damage_text(player_actor, damage, "enemy")
	_play_player_panel_hit()
	player_actor.play_hit(damage, damage)
	_refresh_score_and_turn()

	if player_hp <= 0:
		_end_game("The monster defeated you.")


func _clear_stage() -> void:
	if stage_clear_pending or game_is_over:
		return
	stage_clear_pending = true
	pending_player_attacks = 0
	input_enabled = false
	restart_button.disabled = false
	enemy_actor.play_death()
	save_manager.add_soul(1)
	save_manager.record_stage_progress(stage + 1)
	player_hp = mini(
		run_state.get_player_max_hp(),
		player_hp + run_state.stage_clear_heal
	)
	status_label.text = "Stage %d clear! Choose an upgrade." % stage
	_show_banner("STAGE %d CLEAR  +1 SOUL" % stage, Color("#FFE08A"))
	_refresh_all_ui()
	_show_upgrade_when_board_ready()


func _show_upgrade_when_board_ready() -> void:
	if not stage_clear_pending or game_is_over:
		return
	if is_animating:
		var timer := get_tree().create_timer(0.02)
		timer.timeout.connect(_show_upgrade_when_board_ready)
		return
	_show_upgrade_selection()


func _set_enemy_for_stage() -> void:
	enemy_generation += 1
	enemy_max_hp = BASE_ENEMY_HP + (stage - 1) * ENEMY_HP_GROWTH
	enemy_hp = enemy_max_hp
	enemy_name_label.text = _enemy_name_for_stage(stage)
	if is_instance_valid(enemy_actor):
		enemy_actor.configure_actor(
			enemy_name_label.text,
			stage,
			_enemy_color_for_stage(stage)
		)


func _enemy_name_for_stage(current_stage: int) -> String:
	var names := [
		"SLIME",
		"GOBLIN",
		"STONE GOLEM",
		"DARK MAGE",
		"DRAGON",
	]

	return names[(current_stage - 1) % names.size()]


func _enemy_color_for_stage(current_stage: int) -> Color:
	var colors: Array[Color] = [
		Color("#65A867"),
		Color("#8BAE45"),
		Color("#8C8178"),
		Color("#7453A6"),
		Color("#B64A3B"),
	]
	return colors[(current_stage - 1) % colors.size()]


func _use_ultimate() -> void:
	if game_is_over or not input_enabled:
		return

	var tile_index := logic.find_largest_tile_index(ULTIMATE_MIN_TILE)

	if tile_index < 0:
		status_label.text = "A 64+ tile is required"
		return

	_set_input_locked(true)
	await _animate_ultimate_tile(tile_index)
	var consumed_value: int = logic.consume_tile(tile_index)
	var damage: int = run_state.get_final_ultimate_damage(consumed_value)

	score += consumed_value
	_refresh_board()
	_refresh_score_and_turn()

	status_label.text = (
		"ULTIMATE! Consumed %d → %d damage"
		% [consumed_value, damage]
	)
	_refresh_all_ui()
	_set_input_locked(false)
	_start_player_attack(damage, consumed_value, 1, true, false)


func _check_board_game_over() -> void:
	if pending_player_attacks > 0 or stage_clear_pending:
		return
	if logic.can_move():
		return

	# 64+ tile이 있다면 ultimate로 공간을 만들 수 있으므로 아직 끝나지 않습니다.
	if logic.find_largest_tile_index(ULTIMATE_MIN_TILE) >= 0:
		status_label.text = "No moves. Use ULTIMATE!"
		return

	_end_game("No more moves are available.")


func _end_game(reason: String) -> void:
	if game_is_over:
		return
	game_is_over = true
	input_enabled = false
	is_animating = false
	if not run_recorded:
		save_manager.record_run(stage)
		run_recorded = true
	game_over_reason_label.text = (
		"%s\nStage %d  |  Score %d\nSouls %d  |  Permanent Power +%d%%"
		% [
			reason,
			stage,
			score,
			save_manager.total_souls,
			save_manager.permanent_attack_level * 5,
		]
	)
	_refresh_meta_ui()
	game_over_overlay.visible = true


func _refresh_all_ui() -> void:
	_refresh_board()
	_refresh_score_and_turn()
	_refresh_player_ui()
	_refresh_enemy_ui()
	_refresh_ultimate_button()
	_refresh_meta_ui()


func _refresh_board() -> void:
	for index in range(logic.cells.size()):
		var value: int = logic.cells[index]
		var tile := tile_panels[index]
		var number_label := tile_labels[index]

		tile.add_theme_stylebox_override(
			"panel",
			_create_box_style(_get_tile_color(value), 12)
		)

		number_label.text = "" if value == 0 else str(value)
		number_label.add_theme_font_size_override(
			"font_size",
			_get_font_size(value)
		)
		number_label.add_theme_color_override(
			"font_color",
			_get_text_color(value)
		)

	_refresh_ultimate_button()


func _refresh_score_and_turn() -> void:
	score_label.text = str(score)
	stage_label.text = "STAGE %d" % stage

	var turns_until_attack := (
		run_state.get_enemy_attack_interval()
		- (turn_count % run_state.get_enemy_attack_interval())
	)
	turn_label.text = "ATTACK IN %d" % turns_until_attack
	for index in range(turn_indicators.size()):
		var visible_indicator: bool = index < run_state.get_enemy_attack_interval()
		turn_indicators[index].visible = visible_indicator
		var active: bool = visible_indicator and index < turns_until_attack
		var color := Color("#C6534D") if active else Color("#D9C9C0")
		turn_indicators[index].add_theme_stylebox_override(
			"panel", _create_box_style(color, 7)
		)


func _refresh_player_ui() -> void:
	var max_hp: int = run_state.get_player_max_hp()
	player_hp_label.text = "%d / %d" % [player_hp, max_hp]
	player_hp_bar.max_value = max_hp
	player_hp_bar.value = player_hp


func _refresh_enemy_ui() -> void:
	enemy_hp_bar.max_value = enemy_max_hp
	enemy_hp_bar.value = enemy_hp
	enemy_hp_label.text = "%d / %d" % [enemy_hp, enemy_max_hp]


func _refresh_ultimate_button() -> void:
	var index := logic.find_largest_tile_index(ULTIMATE_MIN_TILE)
	var available: bool = (
		index >= 0
		and not game_is_over
		and not is_animating
		and not stage_clear_pending
		and not build_overlay.visible
	)

	ultimate_button.disabled = not available

	if available:
		var value: int = logic.cells[index]
		ultimate_button.text = (
			"ULTIMATE  |  Consume %d → %d DMG"
			% [value, run_state.get_final_ultimate_damage(value)]
		)
	else:
		ultimate_button.text = "ULTIMATE  |  Need 64+"


func _refresh_meta_ui() -> void:
	meta_label.text = "Souls %d  |  Best %d  |  Power +%d%%" % [
		save_manager.total_souls,
		save_manager.best_stage,
		save_manager.permanent_attack_level * 5,
	]


func _finish_swipe() -> void:
	var delta := touch_current - touch_start

	if delta.length() < SWIPE_MIN_DISTANCE:
		return

	if abs(delta.x) > abs(delta.y):
		if delta.x > 0.0:
			_try_move(BoardLogicScript.Direction.RIGHT)
		else:
			_try_move(BoardLogicScript.Direction.LEFT)
	else:
		if delta.y > 0.0:
			_try_move(BoardLogicScript.Direction.DOWN)
		else:
			_try_move(BoardLogicScript.Direction.UP)


func _start_player_attack(
	damage: int,
	largest_merge: int,
	merge_count: int,
	is_ultimate: bool,
	enemy_attack_due: bool
) -> void:
	if game_is_over or stage_clear_pending:
		return
	pending_player_attacks += 1
	var generation: int = enemy_generation
	var target: Vector2 = _actor_center(enemy_actor)
	if is_ultimate:
		_flash_screen(Color(1.0, 0.82, 0.2, 0.42), 0.22)
		_show_banner("ULTIMATE", Color("#FFF0A6"))
		player_actor.play_ultimate(target, largest_merge)
	else:
		player_actor.play_attack(target, largest_merge)

	_animate_attack_effect(
		_actor_center(player_actor),
		target,
		largest_merge,
		is_ultimate or merge_count >= 2 or largest_merge >= 32,
		_resolve_player_hit.bind(
			damage,
			largest_merge,
			merge_count,
			is_ultimate,
			enemy_attack_due,
			generation
		)
	)


func _resolve_player_hit(
	damage: int,
	largest_merge: int,
	merge_count: int,
	is_ultimate: bool,
	enemy_attack_due: bool,
	generation: int
) -> void:
	if generation != enemy_generation:
		return
	pending_player_attacks = maxi(0, pending_player_attacks - 1)
	if game_is_over or stage_clear_pending:
		return
	_damage_enemy(damage)
	_show_damage_text(
		enemy_actor,
		damage,
		_damage_kind(largest_merge, merge_count, is_ultimate)
	)
	_play_enemy_panel_hit(
		is_ultimate or merge_count >= 2 or largest_merge >= 32
	)
	enemy_actor.play_hit(damage, largest_merge)
	if enemy_hp <= 0:
		_clear_stage()
		return
	if enemy_attack_due:
		_start_enemy_attack(generation)
	_check_board_game_over()


func _animate_tile_moves(move_events: Array) -> void:
	var moving_tiles: Array[PanelContainer] = []
	for index in range(tile_panels.size()):
		_set_tile_display(tile_panels[index], tile_labels[index], 0)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for raw_event: Variant in move_events:
		var event: Dictionary = raw_event
		var from_index: int = int(event["from_index"])
		var to_index: int = int(event["to_index"])
		var value: int = int(event["value"])
		var visual: PanelContainer = _create_tile_visual(value)
		effects_layer.add_child(visual)
		visual.position = _effects_position(tile_panels[from_index].global_position)
		moving_tiles.append(visual)
		tween.tween_property(
			visual,
			"position",
			_effects_position(tile_panels[to_index].global_position),
			TILE_MOVE_DURATION
		).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	await tween.finished
	for visual: PanelContainer in moving_tiles:
		visual.queue_free()


func _animate_merge_pops(move_events: Array) -> void:
	var merge_indices: Array[int] = []
	for raw_event: Variant in move_events:
		var event: Dictionary = raw_event
		if bool(event["merged"]):
			var destination: int = int(event["to_index"])
			if not merge_indices.has(destination):
				merge_indices.append(destination)

	if merge_indices.is_empty():
		return

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	for index: int in merge_indices:
		var tile: PanelContainer = tile_panels[index]
		tile.pivot_offset = tile.size * 0.5
		tile.scale = Vector2(1.18, 1.18)
		tween.tween_property(tile, "scale", Vector2.ONE, MERGE_POP_DURATION).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_OUT)
	await tween.finished


func _animate_spawn_tile(index: int) -> void:
	var tile: PanelContainer = tile_panels[index]
	tile.pivot_offset = tile.size * 0.5
	tile.scale = Vector2.ZERO
	var tween: Tween = create_tween()
	tween.tween_property(tile, "scale", Vector2.ONE, SPAWN_DURATION).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	await tween.finished


func _animate_ultimate_tile(index: int) -> void:
	var tile: PanelContainer = tile_panels[index]
	tile.pivot_offset = tile.size * 0.5
	var tween: Tween = create_tween()
	tween.tween_property(tile, "scale", Vector2(1.2, 1.2), 0.07)
	tween.tween_property(tile, "modulate", Color(1.4, 1.25, 0.55, 1.0), 0.05)
	tween.tween_property(tile, "scale", Vector2.ZERO, 0.1).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_IN)
	await tween.finished
	tile.modulate = Color.WHITE
	tile.scale = Vector2.ONE


func _animate_attack_effect(
	from_position: Vector2,
	to_position: Vector2,
	power: int,
	is_strong: bool,
	on_impact: Callable
) -> void:
	var effect := Label.new()
	effect.text = "✦" if is_strong else "／"
	effect.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	effect.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var effect_size: float = clampf(42.0 + float(power) * 0.25, 42.0, 82.0)
	effect.size = Vector2(effect_size, effect_size)
	effect.pivot_offset = effect.size * 0.5
	effect.add_theme_font_size_override("font_size", int(effect_size))
	effect.add_theme_color_override(
		"font_color", Color("#FFE066") if is_strong else Color.WHITE
	)
	effects_layer.add_child(effect)
	effect.position = _effects_position(from_position) - effect.size * 0.5
	effect.rotation = from_position.angle_to_point(to_position)

	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		effect,
		"position",
		_effects_position(to_position) - effect.size * 0.5,
		0.12 if is_strong else 0.09
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(effect, "scale", Vector2(1.35, 1.35), 0.11)
	tween.finished.connect(_finish_attack_effect.bind(effect, on_impact))


func _finish_attack_effect(effect: Control, on_impact: Callable) -> void:
	if is_instance_valid(effect):
		effect.queue_free()
	if on_impact.is_valid():
		on_impact.call()


func _show_damage_text(target: Control, damage: int, kind: String) -> void:
	var floating_text := Label.new()
	match kind:
		"ultimate":
			floating_text.text = "ULTIMATE  -%d" % damage
		"critical":
			floating_text.text = "CRITICAL  -%d" % damage
		"combo":
			floating_text.text = "COMBO  -%d" % damage
		"power":
			floating_text.text = "POWER  -%d" % damage
		_:
			floating_text.text = "-%d" % damage

	floating_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	floating_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floating_text.size = Vector2(260.0, 64.0)
	floating_text.add_theme_font_size_override(
		"font_size", 34 if kind == "ultimate" else 26
	)
	floating_text.add_theme_color_override(
		"font_color",
		Color("#FFD34E") if kind in ["ultimate", "combo"] else Color("#E54B4B")
	)
	effects_layer.add_child(floating_text)
	floating_text.position = (
		_effects_position(_actor_center(target))
		- Vector2(floating_text.size.x * 0.5, 50.0)
	)
	var start_position: Vector2 = floating_text.position
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(
		floating_text,
		"position",
		start_position - Vector2(0.0, 64.0),
		DAMAGE_TEXT_DURATION
	).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(
		floating_text, "modulate:a", 0.0, DAMAGE_TEXT_DURATION
	).set_delay(0.04)
	tween.finished.connect(floating_text.queue_free)


func _show_banner(text: String, color: Color) -> void:
	var banner := Label.new()
	banner.text = text
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.position = Vector2(-230.0, 250.0)
	banner.size = Vector2(460.0, 80.0)
	banner.add_theme_font_size_override("font_size", 40)
	banner.add_theme_color_override("font_color", color)
	effects_layer.add_child(banner)
	banner.scale = Vector2(0.75, 0.75)
	banner.pivot_offset = banner.size * 0.5
	var tween: Tween = create_tween()
	tween.set_parallel(true)
	tween.tween_property(banner, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_BACK)
	tween.tween_property(banner, "modulate:a", 0.0, 0.34).set_delay(0.14)
	tween.finished.connect(banner.queue_free)


func _flash_screen(color: Color, duration: float) -> void:
	_kill_stored_tween(screen_flash, "flash_tween")
	screen_flash.color = color
	var tween: Tween = create_tween()
	screen_flash.set_meta("flash_tween", tween)
	tween.tween_property(screen_flash, "color:a", 0.0, duration)


func _play_enemy_panel_hit(strong: bool) -> void:
	_kill_stored_tween(enemy_panel, "hit_tween")
	enemy_panel.modulate = Color(1.0, 0.48, 0.48)
	enemy_panel.pivot_offset = enemy_panel.size * 0.5
	enemy_panel.scale = Vector2(1.04, 1.04) if strong else Vector2(1.02, 1.02)
	var tween: Tween = create_tween()
	enemy_panel.set_meta("hit_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(enemy_panel, "modulate", Color.WHITE, 0.1)
	tween.tween_property(enemy_panel, "scale", Vector2.ONE, 0.1)


func _play_player_panel_hit() -> void:
	_kill_stored_tween(player_hp_panel, "hit_tween")
	_kill_stored_tween(player_hp_panel, "shake_tween")
	if not player_hp_panel.has_meta("home_position"):
		player_hp_panel.set_meta("home_position", player_hp_panel.position)
	var home_position: Vector2 = player_hp_panel.get_meta("home_position")
	player_hp_panel.position = home_position
	player_hp_panel.modulate = Color(1.0, 0.48, 0.48)
	var origin: Vector2 = player_hp_panel.position
	var tween: Tween = create_tween()
	player_hp_panel.set_meta("hit_tween", tween)
	tween.set_parallel(true)
	tween.tween_property(player_hp_panel, "modulate", Color.WHITE, 0.1)
	var shake: Tween = create_tween()
	player_hp_panel.set_meta("shake_tween", shake)
	shake.tween_property(player_hp_panel, "position", origin + Vector2(7.0, 0.0), 0.03)
	shake.tween_property(player_hp_panel, "position", origin - Vector2(7.0, 0.0), 0.04)
	shake.tween_property(player_hp_panel, "position", origin, 0.03)


func _kill_stored_tween(node: Node, key: StringName) -> void:
	if not node.has_meta(key):
		return
	var stored: Variant = node.get_meta(key)
	if stored is Tween:
		var tween: Tween = stored
		if tween.is_valid():
			tween.kill()
	node.remove_meta(key)


func _set_attack_indicator_alert() -> void:
	turn_label.text = "ENEMY ATTACK!"
	for indicator: PanelContainer in turn_indicators:
		indicator.add_theme_stylebox_override(
			"panel", _create_box_style(Color("#FF3B30"), 7)
		)


func _set_input_locked(locked: bool) -> void:
	is_animating = locked
	input_enabled = (
		not locked
		and not game_is_over
		and not stage_clear_pending
		and not build_overlay.visible
	)
	touch_active = false
	restart_button.disabled = locked
	build_button.disabled = locked or stage_clear_pending
	_refresh_ultimate_button()


func _damage_kind(
	largest_merge: int,
	merge_count: int,
	is_ultimate: bool
) -> String:
	if is_ultimate:
		return "ultimate"
	if largest_merge >= 64:
		return "critical"
	if merge_count >= 2:
		return "combo"
	if largest_merge >= 32:
		return "power"
	return "normal"


func _show_upgrade_selection() -> void:
	input_enabled = false
	upgrade_overlay.visible = true
	for child: Node in upgrade_cards_row.get_children():
		child.queue_free()

	var candidates: Array[String] = upgrade_system.generate_candidates(
		rng, run_state, 3
	)
	for upgrade_id: String in candidates:
		var definition: Dictionary = upgrade_system.get_definition(upgrade_id)
		var card := Button.new()
		card.custom_minimum_size = Vector2(210.0, 270.0)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.text = "%s\n\n%s\n\n%s\n\n%s\nLevel %d" % [
			str(definition["icon"]),
			str(definition["name"]),
			str(definition["description"]),
			upgrade_system.get_change_text(upgrade_id, run_state),
			run_state.get_upgrade_level(upgrade_id) + 1,
		]
		card.add_theme_font_size_override("font_size", 18)
		card.add_theme_stylebox_override(
			"normal", _create_box_style(Color("#F5EADB"), 15)
		)
		card.add_theme_stylebox_override(
			"hover", _create_box_style(Color("#FFF4CD"), 15)
		)
		card.add_theme_color_override("font_color", Color("#4D443E"))
		card.pressed.connect(_select_upgrade.bind(upgrade_id))
		upgrade_cards_row.add_child(card)


func _select_upgrade(upgrade_id: String) -> void:
	if not upgrade_overlay.visible:
		return
	var previous_max_hp: int = run_state.get_player_max_hp()
	run_state.apply_upgrade(upgrade_id)
	if run_state.get_player_max_hp() > previous_max_hp:
		player_hp += run_state.get_player_max_hp() - previous_max_hp

	upgrade_overlay.visible = false
	stage += 1
	run_state.current_stage = stage
	turn_count = 0
	stage_clear_pending = false
	_set_enemy_for_stage()
	status_label.text = "%s selected — Stage %d" % [
		str(upgrade_system.get_definition(upgrade_id)["name"]),
		stage,
	]
	_refresh_all_ui()
	_set_input_locked(false)


func _show_build_overlay() -> void:
	if stage_clear_pending or game_is_over or is_animating:
		return
	input_enabled = false
	build_details_label.text = _get_build_summary()
	build_overlay.visible = true


func _hide_build_overlay() -> void:
	build_overlay.visible = false
	input_enabled = not game_is_over and not stage_clear_pending and not is_animating


func _get_build_summary() -> String:
	var lines: Array[String] = [
		"Stage: %d" % stage,
		"Attack: %.2fx" % run_state.attack_multiplier,
		"Combo bonus: %.2fx" % run_state.combo_bonus_multiplier,
		"Ultimate: %.2fx" % run_state.ultimate_multiplier,
		"Enemy interval: %d moves" % run_state.get_enemy_attack_interval(),
		"Permanent attack (this run): +%d%%" % roundi(
			(run_state.permanent_attack_multiplier - 1.0) * 100.0
		),
		"Souls: %d    Best Stage: %d" % [
			save_manager.total_souls, save_manager.best_stage
		],
		"Completed runs: %d" % save_manager.total_runs,
		"",
		"UPGRADES",
	]
	var has_upgrade: bool = false
	for upgrade_id: String in UpgradeSystem.ORDERED_IDS:
		var level: int = run_state.get_upgrade_level(upgrade_id)
		if level <= 0:
			continue
		has_upgrade = true
		var definition: Dictionary = upgrade_system.get_definition(upgrade_id)
		lines.append("• %s  Lv.%d" % [str(definition["name"]), level])
	if not has_upgrade:
		lines.append("• No upgrades yet")
	return "\n".join(lines)


func _create_tile_visual(value: int) -> PanelContainer:
	var tile := PanelContainer.new()
	tile.size = TILE_SIZE
	tile.custom_minimum_size = TILE_SIZE
	tile.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tile.add_child(label)
	_set_tile_display(tile, label, value)
	return tile


func _set_tile_display(tile: PanelContainer, label: Label, value: int) -> void:
	tile.add_theme_stylebox_override(
		"panel", _create_box_style(_get_tile_color(value), 12)
	)
	label.text = "" if value == 0 else str(value)
	label.add_theme_font_size_override("font_size", _get_font_size(value))
	label.add_theme_color_override("font_color", _get_text_color(value))


func _actor_center(actor: Control) -> Vector2:
	return actor.global_position + actor.size * 0.5


func _effects_position(global_point: Vector2) -> Vector2:
	return global_point - effects_layer.global_position


func _create_margin_container(
	left: int,
	top: int,
	right: int,
	bottom: int
) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", left)
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_right", right)
	margin.add_theme_constant_override("margin_bottom", bottom)
	return margin


func _create_box_style(color: Color, radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	return style


func _get_tile_color(value: int) -> Color:
	match value:
		0:
			return Color("#C9BCAE")
		2:
			return Color("#EEE4DA")
		4:
			return Color("#EDE0C8")
		8:
			return Color("#F2B179")
		16:
			return Color("#F59563")
		32:
			return Color("#F67C5F")
		64:
			return Color("#F65E3B")
		128:
			return Color("#EDCF72")
		256:
			return Color("#EDCC61")
		512:
			return Color("#EDC850")
		1024:
			return Color("#EDC53F")
		2048:
			return Color("#EDC22E")
		_:
			return Color("#3C3A32")


func _get_text_color(value: int) -> Color:
	if value <= 4:
		return Color("#776E65")

	return Color("#F9F6F2")


func _get_font_size(value: int) -> int:
	if value < 100:
		return 44

	if value < 1000:
		return 37

	if value < 10000:
		return 30

	return 25
