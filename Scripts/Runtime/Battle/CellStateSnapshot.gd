extends RefCounted

class_name CellStateSnapshot


var cell : CellRuntime = null

var x : int = 0

var y : int = 0

var zone : int = CellRuntime.CellZone.NONE

var occupying_unit : UnitRuntime = null


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
	return snapshot


func get_stable_key() -> String:
	return "%04d:%04d" % [y, x]
