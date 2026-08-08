extends Node

class_name BattleInitializer


const PLAYER_1_TEAM_ID : int = 1
const PLAYER_2_TEAM_ID : int = 2


# ============================================================
# ИНИЦИАЛИЗАЦИЯ ТЕСТОВОГО БОЯ
# ============================================================

func initialize_test_battle(
	battle_state : BattleState,
	player_1_units : Array[UnitData],
	player_2_units : Array[UnitData]
) -> bool:
	if battle_state == null:
		push_error("BattleInitializer: BattleState is missing")
		return false

	var player_1_cells := _get_free_deployment_cells(
		battle_state,
		CellRuntime.CellZone.PLAYER_1_DEPLOYMENT
	)
	var player_2_cells := _get_free_deployment_cells(
		battle_state,
		CellRuntime.CellZone.PLAYER_2_DEPLOYMENT
	)

	if player_1_units.size() > player_1_cells.size():
		push_error(
			"BattleInitializer: player 1 roster exceeds free deployment cells"
		)
		return false

	if player_2_units.size() > player_2_cells.size():
		push_error(
			"BattleInitializer: player 2 roster exceeds free deployment cells"
		)
		return false

	var spawned_units : Array[UnitRuntime] = []

	if not _spawn_team(
		battle_state,
		player_1_units,
		player_1_cells,
		PLAYER_1_TEAM_ID,
		spawned_units
	):
		_rollback_spawns(battle_state, spawned_units)
		return false

	if not _spawn_team(
		battle_state,
		player_2_units,
		player_2_cells,
		PLAYER_2_TEAM_ID,
		spawned_units
	):
		_rollback_spawns(battle_state, spawned_units)
		return false

	print(
		"BattleInitializer: spawned ",
		player_1_units.size(),
		" + ",
		player_2_units.size(),
		" units from inspector rosters"
	)
	battle_state.print_units()
	return true


# ============================================================
# ЛИНЕЙНЫЙ АВТОСПАВН
# ============================================================

func _get_free_deployment_cells(
	battle_state : BattleState,
	zone : int
) -> Array[CellRuntime]:
	var result : Array[CellRuntime] = []

	for cell in battle_state.cells:
		if cell == null or cell.zone != zone or not cell.is_empty():
			continue

		result.append(cell)

	# Один и тот же простой порядок для обеих команд: сверху вниз, а внутри
	# строки слева направо. Порядок ресурсов в Inspector совпадает с порядком
	# занятых клеток.
	result.sort_custom(
		func(left : CellRuntime, right : CellRuntime) -> bool:
			if left.y == right.y:
				return left.x < right.x

			return left.y < right.y
	)
	return result


func _spawn_team(
	battle_state : BattleState,
	roster : Array[UnitData],
	deployment_cells : Array[CellRuntime],
	team_id : int,
	spawned_units : Array[UnitRuntime]
) -> bool:
	for unit_index in range(roster.size()):
		var unit_data := roster[unit_index]
		var cell := deployment_cells[unit_index]

		if unit_data == null or cell == null:
			push_error(
				"BattleInitializer: invalid roster entry or deployment cell"
			)
			return false

		var unit := battle_state.spawn_unit(
			unit_data,
			team_id,
			cell.x,
			cell.y
		)

		if unit == null:
			return false

		spawned_units.append(unit)

	return true


func _rollback_spawns(
	battle_state : BattleState,
	spawned_units : Array[UnitRuntime]
) -> void:
	for unit in spawned_units:
		if unit == null:
			continue

		if unit.cell != null:
			unit.cell.remove_unit()

		battle_state.units.erase(unit)
