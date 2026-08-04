extends RefCounted

class_name ImpactExecutor


const RNG_PURPOSE_ARMOR_BLOCK : StringName = &"armor_block"


func validate_plan(
	plan : ImpactPlan,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> PackedStringArray:
	var issues := PackedStringArray()

	if plan == null:
		issues.append("ImpactExecutor: plan is null")
		return issues

	if plan.execution_id == &"":
		issues.append("ImpactExecutor: execution_id is empty")

	if plan.impacts.is_empty():
		issues.append("ImpactExecutor: plan has no impacts")

	if plan.topology not in [
		ImpactPlan.Topology.TREE,
		ImpactPlan.Topology.QUEUE
	]:
		issues.append("ImpactExecutor: plan topology is invalid")

	if snapshot == null:
		issues.append("ImpactExecutor: battle snapshot is null")

	if battle_state == null:
		issues.append("ImpactExecutor: battle_state is null")

	if battle_state != null and battle_state.battle_rng == null:
		issues.append("ImpactExecutor: BattleRng is unavailable")

	var seen_ids : Dictionary = {}

	for impact in plan.impacts:
		if impact == null:
			issues.append("ImpactExecutor: plan contains a null impact")
			continue

		if impact.impact_id == &"":
			issues.append("ImpactExecutor: impact_id is empty")
		elif seen_ids.has(impact.impact_id):
			issues.append(
				"ImpactExecutor: duplicate impact_id '%s'"
				% impact.impact_id
			)
		else:
			seen_ids[impact.impact_id] = true

		if impact.execution_id != plan.execution_id:
			issues.append(
				"ImpactExecutor: impact '%s' has another execution_id"
				% impact.impact_id
			)

		if impact.source_object == null:
			issues.append(
				"ImpactExecutor: impact '%s' has no source object"
				% impact.impact_id
			)

		if impact.source_unit == null:
			issues.append(
				"ImpactExecutor: impact '%s' has no source unit"
				% impact.impact_id
			)
		elif snapshot != null and not snapshot.has_unit(impact.source_unit):
			issues.append(
				"ImpactExecutor: source of impact '%s' is absent from snapshot"
				% impact.impact_id
			)
		elif (
			battle_state != null
			and not battle_state.units.has(impact.source_unit)
		):
			issues.append(
				"ImpactExecutor: source of impact '%s' is absent from battle"
				% impact.impact_id
			)

		if impact.target_unit == null:
			issues.append(
				"ImpactExecutor: impact '%s' has no target unit"
				% impact.impact_id
			)
		elif snapshot != null and not snapshot.has_unit(impact.target_unit):
			issues.append(
				"ImpactExecutor: target of impact '%s' is absent from snapshot"
				% impact.impact_id
			)
		elif (
			battle_state != null
			and not battle_state.units.has(impact.target_unit)
		):
			issues.append(
				"ImpactExecutor: target of impact '%s' is absent from battle"
				% impact.impact_id
			)

		if (
			impact.target_cell != null
			and snapshot != null
			and not snapshot.has_cell(impact.target_cell)
		):
			issues.append(
				(
					"ImpactExecutor: target cell of impact '%s' "
					+ "is absent from snapshot"
				)
				% impact.impact_id
			)
		elif (
			impact.target_cell != null
			and battle_state != null
			and not battle_state.cells.has(impact.target_cell)
		):
			issues.append(
				(
					"ImpactExecutor: target cell of impact '%s' "
					+ "is absent from battle"
				)
				% impact.impact_id
			)

		if impact.operation not in [
			Impact.Operation.DAMAGE,
			Impact.Operation.HEAL,
			Impact.Operation.SUMMON
		]:
			issues.append(
				"ImpactExecutor: impact '%s' has invalid operation"
				% impact.impact_id
			)

		if impact.interaction_type not in [
			Impact.InteractionType.MELEE,
			Impact.InteractionType.RANGED,
			Impact.InteractionType.MAGIC,
			Impact.InteractionType.HEALING,
			Impact.InteractionType.SUMMON
		]:
			issues.append(
				"ImpactExecutor: impact '%s' has invalid interaction type"
				% impact.impact_id
			)

		if (
			impact.operation == Impact.Operation.DAMAGE
			and impact.interaction_type in [
				Impact.InteractionType.HEALING,
				Impact.InteractionType.SUMMON
			]
		):
			issues.append(
				"ImpactExecutor: damage impact '%s' has incompatible interaction"
				% impact.impact_id
			)

		if (
			impact.operation == Impact.Operation.HEAL
			and impact.interaction_type != Impact.InteractionType.HEALING
		):
			issues.append(
				"ImpactExecutor: heal impact '%s' has incompatible interaction"
				% impact.impact_id
			)

		if (
			impact.operation == Impact.Operation.SUMMON
			and impact.interaction_type != Impact.InteractionType.SUMMON
		):
			issues.append(
				"ImpactExecutor: summon impact '%s' has incompatible interaction"
				% impact.impact_id
			)

		if (
			impact.operation == Impact.Operation.DAMAGE
			and impact.source_type == &""
		):
			issues.append(
				"ImpactExecutor: damage impact '%s' has no source type"
				% impact.impact_id
			)

		if impact.magnitude <= 0:
			issues.append(
				"ImpactExecutor: impact '%s' has non-positive magnitude"
				% impact.impact_id
			)

		if impact.operation == Impact.Operation.SUMMON:
			issues.append(
				"ImpactExecutor: SUMMON is not implemented in this stage"
			)

		if plan.topology == ImpactPlan.Topology.QUEUE:
			if impact.parent_impact_id != &"":
				issues.append(
					"ImpactExecutor: queue impact '%s' has a parent"
					% impact.impact_id
				)
		else:
			if (
				impact.parent_impact_id != &""
				and plan.get_impact(impact.parent_impact_id) == null
			):
				issues.append(
					"ImpactExecutor: impact '%s' has a missing parent"
					% impact.impact_id
				)

			if plan.get_depth(impact) > ImpactPlan.MAX_DEPTH:
				issues.append(
					"ImpactExecutor: impact tree exceeds depth %d"
					% ImpactPlan.MAX_DEPTH
				)

	if (
		plan.topology == ImpactPlan.Topology.TREE
		and plan.get_root_impacts().is_empty()
	):
		issues.append("ImpactExecutor: impact tree has no roots")

	return issues


func execute(
	plan : ImpactPlan,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactPlanExecutionResult:
	var result := ImpactPlanExecutionResult.new()
	result.plan = plan
	result.issues = validate_plan(plan, snapshot, battle_state)

	if not result.issues.is_empty():
		result.status = (
			ImpactPlanExecutionResult.Status.VALIDATION_FAILED
		)
		return result

	if plan.topology == ImpactPlan.Topology.QUEUE:
		_execute_queue(plan, snapshot, battle_state, result)
	else:
		_execute_tree(plan, snapshot, battle_state, result)

	result.status = ImpactPlanExecutionResult.Status.EXECUTED
	return result


func _execute_tree(
	plan : ImpactPlan,
	initial_snapshot : BattleStateSnapshot,
	battle_state : BattleState,
	execution_result : ImpactPlanExecutionResult
) -> void:
	var current_layer : Array[Impact] = plan.get_root_impacts()
	var depth : int = 0

	while not current_layer.is_empty():
		var layer_snapshot : BattleStateSnapshot = initial_snapshot

		if depth > 0:
			layer_snapshot = BattleStateSnapshot.capture(battle_state)

		var layer_results : Array[ImpactResult] = []

		for impact in current_layer:
			var impact_result : ImpactResult = null

			if impact.parent_impact_id != &"":
				var parent_result : ImpactResult = execution_result.get_result(
					impact.parent_impact_id
				)

				if parent_result == null or not parent_result.was_applied():
					impact_result = ImpactResult.create(
						impact,
						ImpactResult.Outcome.SKIPPED_PARENT
					)

			if impact_result == null:
				impact_result = _resolve_impact(
					impact,
					layer_snapshot,
					battle_state
				)

			layer_results.append(impact_result)
			execution_result.impact_results.append(impact_result)

		_apply_batch(layer_results, battle_state)

		var next_layer : Array[Impact] = []

		for impact in current_layer:
			next_layer.append_array(
				plan.get_children(impact.impact_id)
			)

		current_layer = next_layer
		depth += 1


func _execute_queue(
	plan : ImpactPlan,
	initial_snapshot : BattleStateSnapshot,
	battle_state : BattleState,
	execution_result : ImpactPlanExecutionResult
) -> void:
	var queue_was_interrupted := false
	var ordered_impacts : Array[Impact] = plan.get_impacts_in_order()

	for impact_index in range(ordered_impacts.size()):
		var impact : Impact = ordered_impacts[impact_index]
		var impact_result : ImpactResult = null

		if queue_was_interrupted:
			impact_result = ImpactResult.create(
				impact,
				ImpactResult.Outcome.SKIPPED_QUEUE_INTERRUPTED
			)
			_print_result(impact_result)
		else:
			var current_snapshot := initial_snapshot

			if impact_index > 0:
				current_snapshot = BattleStateSnapshot.capture(
					battle_state
				)

			impact_result = _resolve_impact(
				impact,
				current_snapshot,
				battle_state
			)
			var single_result_batch : Array[ImpactResult] = [
				impact_result
			]
			_apply_batch(single_result_batch, battle_state)

			if not impact_result.was_applied():
				queue_was_interrupted = true

		execution_result.impact_results.append(impact_result)


func _resolve_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactResult:
	var source_snapshot := snapshot.get_unit_snapshot(
		impact.source_unit
	)

	if source_snapshot == null:
		return ImpactResult.create(
			impact,
			ImpactResult.Outcome.INVALID_SOURCE
		)

	var target_snapshot := snapshot.get_unit_snapshot(
		impact.target_unit
	)

	if target_snapshot == null or not target_snapshot.is_alive:
		return ImpactResult.create(
			impact,
			ImpactResult.Outcome.INVALID_TARGET
		)

	if impact.operation == Impact.Operation.SUMMON:
		return ImpactResult.create(
			impact,
			ImpactResult.Outcome.UNSUPPORTED_OPERATION
		)

	var result := ImpactResult.create(
		impact,
		ImpactResult.Outcome.APPLIED
	)
	result.hp_before = target_snapshot.current_hp

	if impact.operation == Impact.Operation.HEAL:
		result.hp_after = min(
			target_snapshot.max_hp,
			target_snapshot.current_hp + impact.magnitude
		)
		result.magnitude_applied = (
			result.hp_after - result.hp_before
		)
		return result

	if target_snapshot.has_immunity(impact.source_type):
		result.outcome = ImpactResult.Outcome.BLOCKED_IMMUNITY
		result.hp_after = result.hp_before
		return result

	if target_snapshot.has_defense(impact.source_type):
		result.outcome = ImpactResult.Outcome.BLOCKED_DEFENSE
		result.consumed_defense = impact.source_type
		result.hp_after = result.hp_before
		return result

	result.effective_armor = clamp(
		target_snapshot.armor - impact.armor_penetration,
		0,
		5
	)
	result.block_chance = result.effective_armor * 20

	if result.block_chance > 0:
		result.armor_roll = battle_state.battle_rng.roll_int(
			RNG_PURPOSE_ARMOR_BLOCK,
			1,
			100,
			{
				"execution_id": impact.execution_id,
				"impact_id": impact.impact_id,
				"target_name": target_snapshot.unit_name,
				"target_team_id": target_snapshot.team_id,
				"round_number": snapshot.round_number,
				"interaction_type": Impact.get_interaction_type_id(
					impact.interaction_type
				),
				"source_type": impact.source_type,
				"armor": target_snapshot.armor,
				"armor_penetration": impact.armor_penetration,
				"effective_armor": result.effective_armor
			}
		)

		if (
			result.armor_roll != null
			and result.armor_roll.value <= result.block_chance
		):
			result.outcome = ImpactResult.Outcome.BLOCKED_ARMOR
			result.hp_after = result.hp_before
			return result

	result.hp_after = max(
		0,
		target_snapshot.current_hp - impact.magnitude
	)
	result.magnitude_applied = result.hp_before - result.hp_after
	return result


func _apply_batch(
	results : Array[ImpactResult],
	battle_state : BattleState
) -> void:
	for result in results:
		if result == null or result.impact == null:
			continue

		var impact := result.impact
		var target := impact.target_unit

		if target == null:
			continue

		if result.outcome == ImpactResult.Outcome.BLOCKED_DEFENSE:
			target.consume_defense(String(result.consumed_defense))
			_print_result(result)
			continue

		if not result.was_applied():
			_print_result(result)
			continue

		var hp_before_apply := target.current_hp

		if impact.operation == Impact.Operation.DAMAGE:
			target.take_damage(impact.magnitude)
			result.magnitude_applied = max(
				0,
				hp_before_apply - target.current_hp
			)
		elif impact.operation == Impact.Operation.HEAL:
			target.heal(impact.magnitude)
			result.magnitude_applied = max(
				0,
				target.current_hp - hp_before_apply
			)

		result.hp_before = hp_before_apply
		result.hp_after = target.current_hp
		_print_result(result)

	if battle_state != null:
		battle_state.cleanup_dead_units()


func _print_result(result : ImpactResult) -> void:
	if result == null or result.impact == null:
		return

	print(
		"Impact ",
		result.impact.impact_id,
		" | ",
		result.get_outcome_id(),
		" | requested: ",
		result.magnitude_requested,
		" | applied: ",
		result.magnitude_applied
	)
