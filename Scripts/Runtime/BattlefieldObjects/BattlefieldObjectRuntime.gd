extends RefCounted

class_name BattlefieldObjectRuntime


var runtime_id : StringName = &""

var data : BattlefieldObjectData = null

var source_unit : UnitRuntime = null

var source_ability_data : UnitAbilityData = null

var source_team_id : int = 0

var creation_execution_id : StringName = &""

var anchor_cell : CellRuntime = null

var covered_cells : Array[CellRuntime] = []

var created_round_number : int = 0

var remaining_rounds : int = -1

var is_active : bool = false

var is_pending_consumption : bool = false

var processed_event_ids : Dictionary = {}


func setup(
	new_runtime_id : StringName,
	new_data : BattlefieldObjectData,
	new_source_unit : UnitRuntime,
	new_source_ability_data : UnitAbilityData,
	new_execution_id : StringName,
	new_anchor_cell : CellRuntime,
	new_covered_cells : Array[CellRuntime],
	new_created_round_number : int
) -> void:
	runtime_id = new_runtime_id
	data = new_data
	source_unit = new_source_unit
	source_ability_data = new_source_ability_data
	source_team_id = new_source_unit.team_id if new_source_unit != null else 0
	creation_execution_id = new_execution_id
	anchor_cell = new_anchor_cell
	covered_cells.clear()
	covered_cells.append_array(new_covered_cells)
	created_round_number = new_created_round_number
	remaining_rounds = -1

	if data != null and data.lifetime_rounds > 0:
		remaining_rounds = data.lifetime_rounds

	is_active = true
	is_pending_consumption = false
	processed_event_ids.clear()


func get_object_id() -> StringName:
	if data == null:
		return &""

	return StringName(data.object_id)


func covers_cell(cell : CellRuntime) -> bool:
	return is_active and cell != null and covered_cells.has(cell)


func get_living_units_inside() -> Array[UnitRuntime]:
	var result : Array[UnitRuntime] = []

	if not is_active:
		return result

	for cell in covered_cells:
		if (
			cell == null
			or cell.occupying_unit == null
			or not cell.occupying_unit.is_alive
			or result.has(cell.occupying_unit)
		):
			continue

		result.append(cell.occupying_unit)

	return result


func has_processed_event(
	trigger_id : StringName,
	event_id : StringName
) -> bool:
	if trigger_id == &"" or event_id == &"":
		return false

	return processed_event_ids.has(
		_get_trigger_event_key(trigger_id, event_id)
	)


func mark_event_processed(
	trigger_id : StringName,
	event_id : StringName
) -> void:
	if trigger_id == &"" or event_id == &"":
		return

	processed_event_ids[
		_get_trigger_event_key(trigger_id, event_id)
	] = true


func mark_pending_consumption() -> void:
	is_pending_consumption = true


func finish_round(round_number : int) -> bool:
	if not is_active or remaining_rounds < 0:
		return false

	if round_number <= created_round_number:
		return false

	remaining_rounds = maxi(0, remaining_rounds - 1)
	return remaining_rounds == 0


func deactivate() -> void:
	is_active = false
	is_pending_consumption = false


func _get_trigger_event_key(
	trigger_id : StringName,
	event_id : StringName
) -> String:
	return "%s:%s" % [trigger_id, event_id]
