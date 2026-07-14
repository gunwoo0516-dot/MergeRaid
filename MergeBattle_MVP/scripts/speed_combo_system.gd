class_name SpeedComboSystem
extends RefCounted

const BASE_WINDOW := 1.2
const MAX_STACK := 5
const BASE_FEVER_MOVES := 5
const FEVER_SECONDS := 5.0

var stack := 0
var best_stack := 0
var fever_gauge := 0.0
var fever_active := false
var fever_moves_left := 0
var fever_activations := 0
var fever_started_msec := -1
var last_move_msec := -1
var quick_step_level := 0
var momentum_level := 0
var fever_charge_level := 0
var fever_power_level := 0
var long_fever_level := 0
var swift_hands := false
var paused := false

func reset() -> void:
	stack = 0; best_stack = 0; fever_gauge = 0.0; fever_active = false
	fever_moves_left = 0; fever_activations = 0; fever_started_msec = -1; last_move_msec = -1; paused = false

func record_valid_move(now_msec: int) -> Dictionary:
	var old_stack := stack
	if last_move_msec >= 0 and float(now_msec - last_move_msec) / 1000.0 <= get_window(): stack = mini(MAX_STACK, stack + 1)
	else: stack = 1
	last_move_msec = now_msec
	best_stack = maxi(best_stack, stack)
	if stack >= MAX_STACK:
		fever_gauge = minf(100.0, fever_gauge + 22.0 + fever_charge_level * 6.0)
	if fever_active:
		fever_moves_left -= 1
		if fever_moves_left <= 0: end_fever()
	var started := false
	if fever_gauge >= 100.0 and not fever_active:
		started = true; fever_active = true; fever_gauge = 0.0
		fever_moves_left = BASE_FEVER_MOVES + long_fever_level; fever_activations += 1; fever_started_msec = now_msec
	return {"stack_increased":stack > old_stack, "fever_started":started}

func get_window() -> float: return BASE_WINDOW + quick_step_level * 0.15 + (0.2 if swift_hands else 0.0)
func get_remaining_ratio(now_msec: int) -> float:
	if last_move_msec < 0 or paused: return 0.0
	return clampf(1.0 - float(now_msec - last_move_msec) / 1000.0 / get_window(), 0.0, 1.0)
func get_damage_bonus_percent() -> int: return maxi(0, stack - 1) * (5 + momentum_level * 2)
func get_fever_multiplier() -> float: return 1.25 + fever_power_level * 0.08 if fever_active else 1.0
func get_charge_multiplier() -> float: return 1.3 if fever_active else 1.0
func reduce_stack(amount: int) -> void: stack = maxi(0, stack - amount)
func update_timeout(now_msec: int) -> bool:
	if fever_active and not paused and fever_started_msec >= 0 and float(now_msec - fever_started_msec) / 1000.0 >= FEVER_SECONDS:
		end_fever(); return true
	if not fever_active and not paused and last_move_msec >= 0 and float(now_msec - last_move_msec) / 1000.0 > get_window():
		stack = 0; last_move_msec = -1
	return false
func end_fever() -> void: fever_active = false; fever_moves_left = 0; fever_started_msec = -1; stack = 0; last_move_msec = -1
func stop_for_modal() -> void: paused = true
func resume_after_modal() -> void: paused = false; last_move_msec = Time.get_ticks_msec()
