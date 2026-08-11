extends RefCounted

class_name CellStateSnapshot


var cell : CellRuntime = null

var x : int = 0

var y : int = 0

var zone : int = CellRuntime.CellZone.NONE

var occupying_unit : UnitRuntime = null

var covering_objects : Array[BattlefieldObjectRuntime] = []


static func capture(
	runtime_cell : CellRuntime
) -> CellStateSnapshot:
	if runtime_cell == null:
		return null

	var snapshot := CellStateSnapshot.new()
	snapshot.cell = runtime_cell
	snapshot.x = runtime_cell.x
	snapshot.y = runtime_cell.y
	snapshot.zone = runtime_cell.zone
	snapshot.occupying_unit = runtime_cell.occupying_unit

	for object_runtime in runtime_cell.covering_objects:
		if object_runtime != null and object_runtime.is_active:
			snapshot.covering_objects.append(object_runtime)

	return snapshot


func get_defense_provider(
	defense_tag : StringName
) -> BattlefieldObjectRuntime:
	if defense_tag == &"":
		return null

	for object_runtime in covering_objects:
		if (
			object_runtime != null
			and object_runtime.data != null
			and object_runtime.data.provided_defenses.has(String(defense_tag))
		):
			return object_runtime

	return null


func get_stable_key() -> String:
	return "%04d:%04d" % [y, x]
