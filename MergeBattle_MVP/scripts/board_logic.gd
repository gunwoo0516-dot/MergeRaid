class_name BoardLogic
extends RefCounted


const SIZE: int = 4
const CELL_COUNT: int = SIZE * SIZE

enum Direction {
	LEFT,
	RIGHT,
	UP,
	DOWN,
}

var cells: Array[int] = []


func _init() -> void:
	reset()


func reset() -> void:
	cells.clear()

	for index in range(CELL_COUNT):
		cells.append(0)


func move(direction: int) -> Dictionary:
	var before: Array[int] = cells.duplicate()
	var all_merged_values: Array[int] = []
	var move_events: Array[Dictionary] = []

	match direction:
		Direction.LEFT:
			_move_rows(false, all_merged_values, move_events)
		Direction.RIGHT:
			_move_rows(true, all_merged_values, move_events)
		Direction.UP:
			_move_columns(false, all_merged_values, move_events)
		Direction.DOWN:
			_move_columns(true, all_merged_values, move_events)
		_:
			return {
				"changed": false,
				"merged_values": [],
				"merge_score": 0,
				"move_events": [],
			}

	var merge_score: int = 0

	for value in all_merged_values:
		merge_score += value

	return {
		"changed": cells != before,
		"merged_values": all_merged_values,
		"merge_score": merge_score,
		"move_events": move_events,
	}


func spawn_random_tile(rng: RandomNumberGenerator) -> bool:
	return not spawn_random_tile_info(rng).is_empty()


func spawn_random_tile_info(rng: RandomNumberGenerator) -> Dictionary:
	var empty_indices: Array[int] = []

	for index in range(cells.size()):
		if cells[index] == 0:
			empty_indices.append(index)

	if empty_indices.is_empty():
		return {}

	var random_position := rng.randi_range(0, empty_indices.size() - 1)
	var selected_index: int = empty_indices[random_position]

	# 기존 2048과 비슷하게 90% 확률로 2, 10% 확률로 4를 생성합니다.
	var value: int = 4 if rng.randf() < 0.1 else 2
	cells[selected_index] = value
	return {
		"index": selected_index,
		"value": value,
	}


func can_move() -> bool:
	for value in cells:
		if value == 0:
			return true

	for row in range(SIZE):
		for column in range(SIZE):
			var current := get_cell(row, column)

			if column + 1 < SIZE and current == get_cell(row, column + 1):
				return true

			if row + 1 < SIZE and current == get_cell(row + 1, column):
				return true

	return false


func find_largest_tile_index(minimum_value: int) -> int:
	var best_index := -1
	var best_value := minimum_value - 1

	for index in range(cells.size()):
		if cells[index] >= minimum_value and cells[index] > best_value:
			best_index = index
			best_value = cells[index]

	return best_index


func consume_tile(index: int) -> int:
	if index < 0 or index >= cells.size():
		return 0

	var value := cells[index]
	cells[index] = 0
	return value


func get_cell(row: int, column: int) -> int:
	return cells[row * SIZE + column]


func set_cell(row: int, column: int, value: int) -> void:
	cells[row * SIZE + column] = value


func _move_rows(
	reverse_line: bool,
	merged_output: Array[int],
	move_events: Array[Dictionary]
) -> void:
	for row in range(SIZE):
		var line_indices: Array[int] = []

		for column in range(SIZE):
			line_indices.append(row * SIZE + column)

		if reverse_line:
			line_indices.reverse()

		var result := _process_line(line_indices)
		var merged_values: Array[int] = result["merged_values"]
		for value: int in merged_values:
			merged_output.append(int(value))

		var line_events: Array[Dictionary] = result["move_events"]
		move_events.append_array(line_events)


func _move_columns(
	reverse_line: bool,
	merged_output: Array[int],
	move_events: Array[Dictionary]
) -> void:
	for column in range(SIZE):
		var line_indices: Array[int] = []

		for row in range(SIZE):
			line_indices.append(row * SIZE + column)

		if reverse_line:
			line_indices.reverse()

		var result := _process_line(line_indices)
		var merged_values: Array[int] = result["merged_values"]
		for value: int in merged_values:
			merged_output.append(int(value))

		var line_events: Array[Dictionary] = result["move_events"]
		move_events.append_array(line_events)


func _process_line(line_indices: Array[int]) -> Dictionary:
	var occupied_indices: Array[int] = []
	for source_index: int in line_indices:
		if cells[source_index] != 0:
			occupied_indices.append(source_index)

	var final_values: Array[int] = []
	var merged_values: Array[int] = []
	var move_events: Array[Dictionary] = []
	var source_position: int = 0

	while source_position < occupied_indices.size():
		var first_index: int = occupied_indices[source_position]
		var first_value: int = cells[first_index]
		var destination_index: int = line_indices[final_values.size()]
		var has_pair: bool = source_position + 1 < occupied_indices.size()

		if (
			has_pair
			and first_value == cells[occupied_indices[source_position + 1]]
		):
			var second_index: int = occupied_indices[source_position + 1]
			var merged_value: int = first_value * 2
			final_values.append(merged_value)
			merged_values.append(merged_value)
			move_events.append(_make_move_event(
				first_index, destination_index, first_value, true, merged_value, false
			))
			move_events.append(_make_move_event(
				second_index, destination_index, first_value, true, merged_value, true
			))
			source_position += 2
		else:
			final_values.append(first_value)
			move_events.append(_make_move_event(
				first_index, destination_index, first_value, false, 0, false
			))
			source_position += 1

	while final_values.size() < SIZE:
		final_values.append(0)

	for position in range(SIZE):
		cells[line_indices[position]] = final_values[position]

	return {
		"merged_values": merged_values,
		"move_events": move_events,
	}


func _make_move_event(
	from_index: int,
	to_index: int,
	value: int,
	merged: bool,
	merge_value: int,
	removed: bool
) -> Dictionary:
	return {
		"from_index": from_index,
		"to_index": to_index,
		"value": value,
		"merged": merged,
		"merge_value": merge_value,
		"removed": removed,
	}
