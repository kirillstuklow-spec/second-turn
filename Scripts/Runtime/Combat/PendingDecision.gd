extends RefCounted

class_name PendingDecision


enum Kind {
	REACTION_TARGET
}


var decision_id : StringName = &""

var kind : Kind = Kind.REACTION_TARGET

var reason : String = ""

var source_unit : UnitRuntime = null

var source_ability_runtime : UnitAbilityRuntime = null

var reaction_task : ReactionTask = null

var origin_cell : CellRuntime = null

var options : Array[UnitRuntime] = []


func has_option(unit : UnitRuntime) -> bool:
	return unit != null and options.has(unit)


func get_option_cells() -> Array[CellRuntime]:
	var cells : Array[CellRuntime] = []

	for unit in options:
		if unit == null or not unit.is_alive or unit.cell == null:
			continue

		cells.append(unit.cell)

	return cells
