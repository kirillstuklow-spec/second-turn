extends RefCounted

class_name TargetingService


const TARGET_RULE_SINGLE_ANY_ENEMY : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_SINGLE_ANY_ENEMY
)
const TARGET_RULE_SINGLE_ANY_ALLY : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_SINGLE_ANY_ALLY
)
const TARGET_RULE_ALL_ENEMIES : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_ALL_ENEMIES
)
const TARGET_RULE_SINGLE_ADJACENT_ENEMY : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_SINGLE_ADJACENT_ENEMY
)
const TARGET_RULE_AREA_AROUND_UNIT : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_AREA_AROUND_UNIT
)
const TARGET_RULE_AREA_AROUND_CELL : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_AREA_AROUND_CELL
)

const TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL : StringName = (
	AbilityAlgorithmRegistry.TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL
)

const PARAM_RADIUS : StringName = AbilityAlgorithmRegistry.PARAM_RADIUS

const CONDITION_TARGET_MUST_BE_ALIVE : StringName = (
	AbilityAlgorithmRegistry.CONDITION_TARGET_MUST_BE_ALIVE
)
const CONDITION_TARGET_MUST_BE_ENEMY : StringName = (
	AbilityAlgorithmRegistry.CONDITION_TARGET_MUST_BE_ENEMY
)
const CONDITION_TARGET_MUST_BE_ALLY : StringName = (
	AbilityAlgorithmRegistry.CONDITION_TARGET_MUST_BE_ALLY
)


func resolve(
	battle_state : BattleState,
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	target_cell : CellRuntime,
	unit_ability : UnitAbilityData,
	resolved_parameters : Dictionary
) -> TargetingResult:
	var result := TargetingResult.new()

	if battle_state == null:
		return result.reject(
			TargetingResult.Reason.BATTLE_STATE_MISSING
		)

	if source_unit == null:
		return result.reject(
			TargetingResult.Reason.SOURCE_MISSING
		)

	if (
		unit_ability == null
		or unit_ability.ability == null
	):
		return result.reject(
			TargetingResult.Reason.ABILITY_MISSING
		)

	var snapshot := BattleStateSnapshot.capture(battle_state)

	if snapshot == null:
		return result.reject(
			TargetingResult.Reason.BATTLE_STATE_MISSING
		)

	return _resolve_with_snapshot(
		snapshot,
		source_unit,
		target_unit,
		target_cell,
		unit_ability,
		resolved_parameters
	)


func get_valid_selection_cells(
	battle_state : BattleState,
	source_unit : UnitRuntime,
	unit_ability : UnitAbilityData,
	resolved_parameters : Dictionary
) -> Array[CellRuntime]:
	var valid_cells : Array[CellRuntime] = []

	if (
		battle_state == null
		or source_unit == null
		or unit_ability == null
		or unit_ability.ability == null
	):
		return valid_cells

	var snapshot := BattleStateSnapshot.capture(battle_state)

	if snapshot == null:
		return valid_cells

	var source_snapshot := snapshot.get_unit_snapshot(source_unit)

	if source_snapshot == null or not source_snapshot.is_alive:
		return valid_cells

	var target_rule_id := StringName(
		unit_ability.ability.target_rule_id
	)

	if target_rule_id == TARGET_RULE_ALL_ENEMIES:
		for unit_snapshot in snapshot.unit_snapshots:
			if _get_unit_rejection_reason(
				source_snapshot,
				unit_snapshot,
				unit_ability
			) != TargetingResult.Reason.NONE:
				continue

			if unit_snapshot.cell != null:
				valid_cells.append(unit_snapshot.cell)

		return valid_cells

	for cell_snapshot in snapshot.cell_snapshots:
		if cell_snapshot == null or cell_snapshot.cell == null:
			continue

		var candidate_unit : UnitRuntime = (
			cell_snapshot.occupying_unit
		)
		var candidate_result := _resolve_with_snapshot(
			snapshot,
			source_unit,
			candidate_unit,
			cell_snapshot.cell,
			unit_ability,
			resolved_parameters
		)

		if candidate_result.is_valid:
			valid_cells.append(cell_snapshot.cell)

	return valid_cells


# Реакция может исходить от уже погибшего юнита. Поэтому здесь намеренно
# не требуется is_alive источника: принадлежность команды берётся из его
# сохранённого Runtime, а пространственное правило — из клетки события.
func get_valid_triggered_target_units(
	battle_state : BattleState,
	source_unit : UnitRuntime,
	origin_cell : CellRuntime,
	unit_ability : UnitAbilityData
) -> Array[UnitRuntime]:
	var valid_units : Array[UnitRuntime] = []

	if (
		battle_state == null
		or source_unit == null
		or unit_ability == null
		or unit_ability.ability == null
	):
		return valid_units

	var snapshot := BattleStateSnapshot.capture(battle_state)

	if snapshot == null:
		return valid_units

	var source_snapshot := snapshot.get_unit_snapshot(source_unit)

	if source_snapshot == null:
		return valid_units

	var target_rule_id := StringName(
		unit_ability.ability.target_rule_id
	)

	for target_snapshot in snapshot.unit_snapshots:
		if (
			_get_unit_rejection_reason(
				source_snapshot,
				target_snapshot,
				unit_ability
			)
			!= TargetingResult.Reason.NONE
		):
			continue

		match target_rule_id:
			TARGET_RULE_SINGLE_ADJACENT_ENEMY:
				if (
					origin_cell == null
					or target_snapshot.cell == null
					or (
						abs(origin_cell.x - target_snapshot.cell_x)
						+ abs(origin_cell.y - target_snapshot.cell_y)
						!= 1
					)
				):
					continue

			TARGET_RULE_SINGLE_ANY_ENEMY, TARGET_RULE_SINGLE_ANY_ALLY:
				pass

			_:
				continue

		valid_units.append(target_snapshot.unit)

	return valid_units


func is_valid_triggered_target(
	battle_state : BattleState,
	source_unit : UnitRuntime,
	origin_cell : CellRuntime,
	unit_ability : UnitAbilityData,
	target_unit : UnitRuntime
) -> bool:
	return get_valid_triggered_target_units(
		battle_state,
		source_unit,
		origin_cell,
		unit_ability
	).has(target_unit)


func _resolve_with_snapshot(
	snapshot : BattleStateSnapshot,
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	target_cell : CellRuntime,
	unit_ability : UnitAbilityData,
	resolved_parameters : Dictionary
) -> TargetingResult:
	var result := TargetingResult.new()
	result.snapshot = snapshot
	result.source_snapshot = snapshot.get_unit_snapshot(source_unit)

	if result.source_snapshot == null:
		return result.reject(
			TargetingResult.Reason.SOURCE_NOT_IN_BATTLE
		)

	if not result.source_snapshot.is_alive:
		return result.reject(
			TargetingResult.Reason.SOURCE_NOT_ALIVE
		)

	var ability_data := unit_ability.ability
	var target_rule_id := StringName(ability_data.target_rule_id)

	if target_rule_id == TARGET_RULE_ALL_ENEMIES:
		if target_unit != null:
			result.selected_unit_snapshot = snapshot.get_unit_snapshot(
				target_unit
			)

			if result.selected_unit_snapshot == null:
				return result.reject(
					TargetingResult.Reason.TARGET_UNIT_NOT_IN_BATTLE
				)

			if target_cell != null:
				result.selected_cell_snapshot = (
					snapshot.get_cell_snapshot(target_cell)
				)

				if result.selected_cell_snapshot == null:
					return result.reject(
						TargetingResult.Reason.TARGET_CELL_NOT_IN_BATTLE
					)

				if result.selected_unit_snapshot.cell != target_cell:
					return result.reject(
						TargetingResult.Reason.TARGET_UNIT_CELL_MISMATCH
					)

			var selection_rejection := _get_unit_rejection_reason(
				result.source_snapshot,
				result.selected_unit_snapshot,
				unit_ability
			)

			if selection_rejection != TargetingResult.Reason.NONE:
				return result.reject(selection_rejection)

		_collect_all_valid_units(
			result,
			unit_ability
		)
		return _require_nonempty_unit_targets(result)

	if target_rule_id == TARGET_RULE_AREA_AROUND_CELL:
		return _resolve_area_around_cell(
			result,
			target_cell,
			unit_ability,
			resolved_parameters
		)

	if target_rule_id == TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL:
		return _resolve_empty_deployment_cell(
			result,
			target_cell
		)

	if target_unit == null:
		return result.reject(
			TargetingResult.Reason.TARGET_UNIT_REQUIRED
		)

	result.selected_unit_snapshot = snapshot.get_unit_snapshot(
		target_unit
	)

	if result.selected_unit_snapshot == null:
		return result.reject(
			TargetingResult.Reason.TARGET_UNIT_NOT_IN_BATTLE
		)

	if target_cell != null:
		result.selected_cell_snapshot = snapshot.get_cell_snapshot(
			target_cell
		)

		if result.selected_cell_snapshot == null:
			return result.reject(
				TargetingResult.Reason.TARGET_CELL_NOT_IN_BATTLE
			)

		if result.selected_unit_snapshot.cell != target_cell:
			return result.reject(
				TargetingResult.Reason.TARGET_UNIT_CELL_MISMATCH
			)

	var unit_rejection_reason := _get_unit_rejection_reason(
		result.source_snapshot,
		result.selected_unit_snapshot,
		unit_ability
	)

	if unit_rejection_reason != TargetingResult.Reason.NONE:
		return result.reject(unit_rejection_reason)

	if target_rule_id == TARGET_RULE_SINGLE_ADJACENT_ENEMY:
		if not _are_snapshots_adjacent(
			result.source_snapshot,
			result.selected_unit_snapshot
		):
			return result.reject(
				TargetingResult.Reason.TARGET_NOT_ADJACENT
			)

	if target_rule_id == TARGET_RULE_AREA_AROUND_UNIT:
		return _resolve_area_around_unit(
			result,
			unit_ability,
			resolved_parameters
		)

	if (
		target_rule_id != TARGET_RULE_SINGLE_ANY_ENEMY
		and target_rule_id != TARGET_RULE_SINGLE_ANY_ALLY
		and target_rule_id != TARGET_RULE_SINGLE_ADJACENT_ENEMY
	):
		return result.reject(
			TargetingResult.Reason.TARGET_RULE_UNSUPPORTED,
			{
				"target_rule_id": target_rule_id
			}
		)

	result.target_unit_snapshots.append(
		result.selected_unit_snapshot
	)
	return result


func _resolve_area_around_unit(
	result : TargetingResult,
	unit_ability : UnitAbilityData,
	resolved_parameters : Dictionary
) -> TargetingResult:
	if (
		result.selected_unit_snapshot == null
		or result.selected_unit_snapshot.cell == null
	):
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_REQUIRED
		)

	var radius := int(resolved_parameters.get(PARAM_RADIUS, 0))

	for possible_target in result.snapshot.unit_snapshots:
		if possible_target == null or possible_target.cell == null:
			continue

		if not _is_in_radius(
			result.selected_unit_snapshot.cell_x,
			result.selected_unit_snapshot.cell_y,
			possible_target.cell_x,
			possible_target.cell_y,
			radius
		):
			continue

		if _get_unit_rejection_reason(
			result.source_snapshot,
			possible_target,
			unit_ability
		) != TargetingResult.Reason.NONE:
			continue

		result.target_unit_snapshots.append(possible_target)

	return _require_nonempty_unit_targets(result)


func _resolve_area_around_cell(
	result : TargetingResult,
	target_cell : CellRuntime,
	unit_ability : UnitAbilityData,
	resolved_parameters : Dictionary
) -> TargetingResult:
	if target_cell == null:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_REQUIRED
		)

	result.selected_cell_snapshot = result.snapshot.get_cell_snapshot(
		target_cell
	)

	if result.selected_cell_snapshot == null:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_NOT_IN_BATTLE
		)

	var radius := int(resolved_parameters.get(PARAM_RADIUS, 0))

	for possible_target in result.snapshot.unit_snapshots:
		if possible_target == null or possible_target.cell == null:
			continue

		if not _is_in_radius(
			result.selected_cell_snapshot.x,
			result.selected_cell_snapshot.y,
			possible_target.cell_x,
			possible_target.cell_y,
			radius
		):
			continue

		if _get_unit_rejection_reason(
			result.source_snapshot,
			possible_target,
			unit_ability
		) != TargetingResult.Reason.NONE:
			continue

		result.target_unit_snapshots.append(possible_target)

	result.target_cell_snapshots.append(
		result.selected_cell_snapshot
	)
	return _require_nonempty_unit_targets(result)


func _resolve_empty_deployment_cell(
	result : TargetingResult,
	target_cell : CellRuntime
) -> TargetingResult:
	if target_cell == null:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_REQUIRED
		)

	result.selected_cell_snapshot = result.snapshot.get_cell_snapshot(
		target_cell
	)

	if result.selected_cell_snapshot == null:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_NOT_IN_BATTLE
		)

	if result.selected_cell_snapshot.occupying_unit != null:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_OCCUPIED
		)

	var expected_zone := CellRuntime.CellZone.PLAYER_1_DEPLOYMENT

	if result.source_snapshot.team_id == 2:
		expected_zone = CellRuntime.CellZone.PLAYER_2_DEPLOYMENT

	if result.selected_cell_snapshot.zone != expected_zone:
		return result.reject(
			TargetingResult.Reason.TARGET_CELL_WRONG_ZONE
		)

	result.target_cell_snapshots.append(
		result.selected_cell_snapshot
	)
	return result


func _collect_all_valid_units(
	result : TargetingResult,
	unit_ability : UnitAbilityData
) -> void:
	for possible_target in result.snapshot.unit_snapshots:
		if _get_unit_rejection_reason(
			result.source_snapshot,
			possible_target,
			unit_ability
		) == TargetingResult.Reason.NONE:
			result.target_unit_snapshots.append(possible_target)


func _get_unit_rejection_reason(
	source_snapshot : UnitStateSnapshot,
	target_snapshot : UnitStateSnapshot,
	unit_ability : UnitAbilityData
) -> TargetingResult.Reason:
	if source_snapshot == null:
		return TargetingResult.Reason.SOURCE_NOT_IN_BATTLE

	if target_snapshot == null:
		return TargetingResult.Reason.TARGET_UNIT_REQUIRED

	if not target_snapshot.is_alive:
		return TargetingResult.Reason.TARGET_NOT_ALIVE

	var action_type := unit_ability.ability.action_type

	if (
		action_type == AbilityData.ActionType.ATTACK
		and source_snapshot.team_id == target_snapshot.team_id
	):
		return TargetingResult.Reason.TARGET_NOT_ENEMY

	if (
		action_type == AbilityData.ActionType.HEAL
		and source_snapshot.team_id != target_snapshot.team_id
	):
		return TargetingResult.Reason.TARGET_NOT_ALLY

	var all_conditions : Array[String] = []
	all_conditions.append_array(
		unit_ability.ability.default_conditions
	)
	all_conditions.append_array(unit_ability.conditions)

	for raw_condition_id in all_conditions:
		var condition_id := StringName(raw_condition_id)

		if (
			condition_id == CONDITION_TARGET_MUST_BE_ALIVE
			and not target_snapshot.is_alive
		):
			return TargetingResult.Reason.TARGET_NOT_ALIVE

		if (
			condition_id == CONDITION_TARGET_MUST_BE_ENEMY
			and source_snapshot.team_id == target_snapshot.team_id
		):
			return TargetingResult.Reason.TARGET_NOT_ENEMY

		if (
			condition_id == CONDITION_TARGET_MUST_BE_ALLY
			and source_snapshot.team_id != target_snapshot.team_id
		):
			return TargetingResult.Reason.TARGET_NOT_ALLY

		if (
			condition_id != CONDITION_TARGET_MUST_BE_ALIVE
			and condition_id != CONDITION_TARGET_MUST_BE_ENEMY
			and condition_id != CONDITION_TARGET_MUST_BE_ALLY
		):
			return TargetingResult.Reason.CONDITION_FAILED

	return TargetingResult.Reason.NONE


func _require_nonempty_unit_targets(
	result : TargetingResult
) -> TargetingResult:
	if result.target_unit_snapshots.is_empty():
		return result.reject(
			TargetingResult.Reason.NO_VALID_TARGETS
		)

	return result


func _are_snapshots_adjacent(
	left : UnitStateSnapshot,
	right : UnitStateSnapshot
) -> bool:
	if (
		left == null
		or right == null
		or left.cell == null
		or right.cell == null
	):
		return false

	return (
		abs(left.cell_x - right.cell_x)
		+ abs(left.cell_y - right.cell_y)
		== 1
	)


func _is_in_radius(
	center_x : int,
	center_y : int,
	target_x : int,
	target_y : int,
	radius : int
) -> bool:
	return (
		abs(center_x - target_x)
		+ abs(center_y - target_y)
		<= radius
	)
