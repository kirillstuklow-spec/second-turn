extends RefCounted

class_name BattleStateSnapshot


var round_number : int = 0

var rng_state : int = 0

var is_battle_over : bool = false

var unit_snapshots : Array[UnitStateSnapshot] = []

var cell_snapshots : Array[CellStateSnapshot] = []


static func capture(
	battle_state : BattleState
) -> BattleStateSnapshot:
	if battle_state == null:
		return null

	var snapshot := BattleStateSnapshot.new()
	snapshot.round_number = battle_state.round_number
	snapshot.is_battle_over = battle_state.is_battle_over

	if battle_state.battle_rng != null:
		snapshot.rng_state = battle_state.battle_rng.current_state

	for runtime_cell in battle_state.cells:
		var cell_snapshot := CellStateSnapshot.capture(runtime_cell)

		if cell_snapshot != null:
			snapshot.cell_snapshots.append(cell_snapshot)

	for runtime_unit in battle_state.units:
		var unit_snapshot := UnitStateSnapshot.capture(runtime_unit)

		if unit_snapshot != null:
			snapshot.unit_snapshots.append(unit_snapshot)

	snapshot.cell_snapshots.sort_custom(
		func(
			left : CellStateSnapshot,
			right : CellStateSnapshot
		) -> bool:
			return left.get_stable_key() < right.get_stable_key()
	)

	snapshot.unit_snapshots.sort_custom(
		func(
			left : UnitStateSnapshot,
			right : UnitStateSnapshot
		) -> bool:
			return left.get_stable_key() < right.get_stable_key()
	)

	return snapshot


func get_unit_snapshot(
	runtime_unit : UnitRuntime
) -> UnitStateSnapshot:
	if runtime_unit == null:
		return null

	for unit_snapshot in unit_snapshots:
		if (
			unit_snapshot != null
			and unit_snapshot.unit == runtime_unit
		):
			return unit_snapshot

	return null


func get_cell_snapshot(
	runtime_cell : CellRuntime
) -> CellStateSnapshot:
	if runtime_cell == null:
		return null

	for cell_snapshot in cell_snapshots:
		if (
			cell_snapshot != null
			and cell_snapshot.cell == runtime_cell
		):
			return cell_snapshot

	return null


func get_cell_snapshot_at(
	x : int,
	y : int
) -> CellStateSnapshot:
	for cell_snapshot in cell_snapshots:
		if (
			cell_snapshot != null
			and cell_snapshot.x == x
			and cell_snapshot.y == y
		):
			return cell_snapshot

	return null


func has_unit(runtime_unit : UnitRuntime) -> bool:
	return get_unit_snapshot(runtime_unit) != null


func has_cell(runtime_cell : CellRuntime) -> bool:
	return get_cell_snapshot(runtime_cell) != null
