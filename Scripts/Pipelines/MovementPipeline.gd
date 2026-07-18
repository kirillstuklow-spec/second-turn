extends Node

class_name MovementPipeline


# ============================================================
# ССЫЛКИ НА СОСТОЯНИЕ БОЯ
# ============================================================

var battle_state : BattleState = null
var event_queue : EventQueue = null


# ============================================================
# НАСТРОЙКА PIPELINE
# ============================================================

func configure(
	new_battle_state : BattleState,
	new_event_queue : EventQueue
) -> void:
	battle_state = new_battle_state
	event_queue = new_event_queue

	print("MovementPipeline configured")


# ============================================================
# ВЫПОЛНЕНИЕ ДВИЖЕНИЯ
# ============================================================

func execute_move(
	unit : UnitRuntime,
	target_cell : CellRuntime
) -> bool:
	if battle_state == null:
		push_error("MovementPipeline: battle_state is null")
		return false

	if unit == null:
		push_error("MovementPipeline: unit is null")
		return false

	if target_cell == null:
		push_error("MovementPipeline: target_cell is null")
		return false

	if not unit.can_spend_movement_points(1):
		print("MovementPipeline: not enough movement points")
		_push_event({
			"type": "MoveFailed",
			"reason": "not_enough_movement_points",
			"unit_name": unit.data.unit_name,
			"target_x": target_cell.x,
			"target_y": target_cell.y
		})
		return false

	print("MovementPipeline: move command received")
	print("Unit: ", unit.data.unit_name)
	print("Target cell: ", target_cell.x, ",", target_cell.y)

	var old_cell : CellRuntime = unit.cell
	var old_x : int = -1
	var old_y : int = -1

	if old_cell != null:
		old_x = old_cell.x
		old_y = old_cell.y

	var move_successful : bool = battle_state.move_unit(unit, target_cell)

	if not move_successful:
		_push_event({
			"type": "MoveFailed",
			"unit_name": unit.data.unit_name,
			"target_x": target_cell.x,
			"target_y": target_cell.y
		})
		return false

	unit.spend_movement_points(1)

	_push_event({
		"type": "UnitMoved",
		"unit_name": unit.data.unit_name,
		"from_x": old_x,
		"from_y": old_y,
		"to_x": target_cell.x,
		"to_y": target_cell.y,
		"movement_points_remaining": unit.movement_points_remaining
	})

	return true


# ============================================================
# EVENT QUEUE
# ============================================================

func _push_event(event : Dictionary) -> void:
	if event_queue == null:
		return

	event_queue.push_event(event)
