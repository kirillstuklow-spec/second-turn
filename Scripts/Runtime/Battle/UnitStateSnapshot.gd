extends RefCounted

class_name UnitStateSnapshot


var unit : UnitRuntime = null

var unit_id : StringName = &""

var unit_name : String = ""

var team_id : int = 0

var current_hp : int = 0

var max_hp : int = 0

var armor : int = 0

var is_alive : bool = false

var death_state : UnitRuntime.DeathState = UnitRuntime.DeathState.ALIVE

var cell : CellRuntime = null

var cell_x : int = -1

var cell_y : int = -1

var death_origin_cell : CellRuntime = null

var death_origin_x : int = -1

var death_origin_y : int = -1

var active_defenses : Array[String] = []

var active_immunities : Array[String] = []

var active_effect_ids : Array[StringName] = []


static func capture(
	runtime_unit : UnitRuntime
) -> UnitStateSnapshot:
	if runtime_unit == null:
		return null

	var snapshot := UnitStateSnapshot.new()
	snapshot.unit = runtime_unit
	snapshot.team_id = runtime_unit.team_id
	snapshot.current_hp = runtime_unit.current_hp
	snapshot.armor = runtime_unit.armor
	snapshot.is_alive = runtime_unit.is_alive
	snapshot.death_state = runtime_unit.death_state
	snapshot.cell = runtime_unit.cell
	snapshot.death_origin_cell = runtime_unit.death_origin_cell
	snapshot.death_origin_x = runtime_unit.death_origin_x
	snapshot.death_origin_y = runtime_unit.death_origin_y
	snapshot.active_defenses = (
		runtime_unit.active_defenses.duplicate()
	)
	snapshot.active_immunities = (
		runtime_unit.active_immunities.duplicate()
	)

	for effect_runtime in runtime_unit.active_effects:
		if effect_runtime != null:
			snapshot.active_effect_ids.append(
				effect_runtime.get_effect_id()
			)

	if runtime_unit.data != null:
		snapshot.unit_id = StringName(runtime_unit.data.unit_id)
		snapshot.unit_name = runtime_unit.data.unit_name
		snapshot.max_hp = runtime_unit.data.max_hp

	if runtime_unit.cell != null:
		snapshot.cell_x = runtime_unit.cell.x
		snapshot.cell_y = runtime_unit.cell.y

	return snapshot


func has_defense(source_type : StringName) -> bool:
	if source_type == &"":
		return false

	return active_defenses.has(String(source_type))


func has_immunity(source_type : StringName) -> bool:
	if source_type == &"":
		return false

	return active_immunities.has(String(source_type))


func get_stable_key() -> String:
	if cell != null:
		return "%04d:%04d:%02d:%s" % [
			cell_y,
			cell_x,
			team_id,
			String(unit_id)
		]

	return "off_field:%02d:%s:%s" % [
		team_id,
		String(unit_id),
		unit_name
	]
