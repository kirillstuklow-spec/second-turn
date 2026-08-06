extends RefCounted

class_name ImpactExecutor


const RNG_PURPOSE_ARMOR_BLOCK : StringName = (
	InteractionResolver.RNG_PURPOSE_ARMOR_BLOCK
)


var interaction_resolver : InteractionResolver = InteractionResolver.new()

var status_effect_system : StatusEffectSystem = StatusEffectSystem.new()

var combat_event_log : CombatEventLog = CombatEventLog.new()

var reaction_queue : ReactionQueue = ReactionQueue.new()

var reaction_system : ReactionSystem = ReactionSystem.new()

var condition_evaluator : ImpactConditionEvaluator = (
	ImpactConditionEvaluator.new()
)

var _reaction_plan_builder : AbilityImpactPlanBuilder = (
	AbilityImpactPlanBuilder.new()
)

var _is_draining_reactions : bool = false


func _init() -> void:
	reaction_system.configure(
		reaction_queue,
		_reaction_plan_builder
	)


func configure(
	new_interaction_resolver : InteractionResolver,
	new_status_effect_system : StatusEffectSystem = null,
	new_combat_event_log : CombatEventLog = null,
	new_reaction_queue : ReactionQueue = null,
	new_reaction_system : ReactionSystem = null,
	new_condition_evaluator : ImpactConditionEvaluator = null,
	new_reaction_plan_builder : AbilityImpactPlanBuilder = null
) -> void:
	interaction_resolver = new_interaction_resolver

	if interaction_resolver == null:
		interaction_resolver = InteractionResolver.new()

	if new_status_effect_system != null:
		status_effect_system = new_status_effect_system

	if new_combat_event_log != null:
		combat_event_log = new_combat_event_log

	if new_reaction_queue != null:
		reaction_queue = new_reaction_queue

	if new_reaction_system != null:
		reaction_system = new_reaction_system

	if new_condition_evaluator != null:
		condition_evaluator = new_condition_evaluator

	if new_reaction_plan_builder != null:
		_reaction_plan_builder = new_reaction_plan_builder

	if status_effect_system == null:
		status_effect_system = StatusEffectSystem.new()

	if combat_event_log == null:
		combat_event_log = CombatEventLog.new()

	if reaction_queue == null:
		reaction_queue = ReactionQueue.new()

	if reaction_system == null:
		reaction_system = ReactionSystem.new()

	if condition_evaluator == null:
		condition_evaluator = ImpactConditionEvaluator.new()

	if _reaction_plan_builder == null:
		_reaction_plan_builder = AbilityImpactPlanBuilder.new()

	reaction_system.configure(
		reaction_queue,
		_reaction_plan_builder
	)


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

	if interaction_resolver == null:
		issues.append("ImpactExecutor: InteractionResolver is unavailable")

	if status_effect_system == null:
		issues.append("ImpactExecutor: StatusEffectSystem is unavailable")

	var seen_ids : Dictionary = {}

	for impact in plan.impacts:
		_validate_impact(
			impact,
			plan,
			snapshot,
			battle_state,
			seen_ids,
			issues
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
	var is_outer_execution := not _is_draining_reactions
	var result := _execute_plan_core(plan, snapshot, battle_state)

	if result.is_successful() and is_outer_execution:
		_drain_reactions(battle_state, result)

	if battle_state != null and is_outer_execution:
		battle_state.cleanup_dead_units()

	return result


# Проводит системное событие (например, окончание активации) через ту же
# очередь реакций, что и события от Impact. TurnPipeline публикует момент
# времени, а конкретные эффекты остаются декларативными.
func process_unit_event(
	event_kind : CombatEvent.Kind,
	unit : UnitRuntime,
	battle_state : BattleState
) -> ImpactPlanExecutionResult:
	var result := ImpactPlanExecutionResult.new()

	if battle_state == null:
		result.status = ImpactPlanExecutionResult.Status.INTERNAL_ERROR
		result.issues.append(
			"ImpactExecutor: battle_state is null for unit event"
		)
		return result

	if unit == null:
		result.status = ImpactPlanExecutionResult.Status.INTERNAL_ERROR
		result.issues.append(
			"ImpactExecutor: unit is null for unit event"
		)
		return result

	if combat_event_log == null or reaction_system == null:
		result.status = ImpactPlanExecutionResult.Status.INTERNAL_ERROR
		result.issues.append(
			"ImpactExecutor: combat event infrastructure is unavailable"
		)
		return result

	var event := combat_event_log.record_unit_event(
		event_kind,
		unit,
		battle_state
	)

	if event == null:
		result.status = ImpactPlanExecutionResult.Status.INTERNAL_ERROR
		result.issues.append(
			"ImpactExecutor: unit event could not be recorded"
		)
		return result

	result.status = ImpactPlanExecutionResult.Status.EXECUTED
	reaction_system.collect_reactions(event, battle_state)
	_drain_reactions(battle_state, result)
	battle_state.cleanup_dead_units()
	return result


func _execute_plan_core(
	plan : ImpactPlan,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactPlanExecutionResult:
	var result := ImpactPlanExecutionResult.new()
	result.plan = plan
	result.issues = validate_plan(plan, snapshot, battle_state)

	if not result.issues.is_empty():
		result.status = ImpactPlanExecutionResult.Status.VALIDATION_FAILED
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
				var parent_result := execution_result.get_result(
					impact.parent_impact_id
				)

				if parent_result == null:
					impact_result = ImpactResult.create(
						impact,
						ImpactResult.Outcome.SKIPPED_PARENT
					)
				elif (
					impact.transition_condition == null
					and not parent_result.was_applied()
				):
					impact_result = ImpactResult.create(
						impact,
						ImpactResult.Outcome.SKIPPED_PARENT
					)
				elif not condition_evaluator.is_satisfied(
					impact.transition_condition,
					parent_result
				):
					impact_result = ImpactResult.create(
						impact,
						ImpactResult.Outcome.SKIPPED_CONDITION
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
			next_layer.append_array(plan.get_children(impact.impact_id))

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
				current_snapshot = BattleStateSnapshot.capture(battle_state)

			impact_result = _resolve_impact(
				impact,
				current_snapshot,
				battle_state
			)
			var single_result_batch : Array[ImpactResult] = [impact_result]
			_apply_batch(single_result_batch, battle_state)

			if not impact_result.was_applied():
				queue_was_interrupted = true

		execution_result.impact_results.append(impact_result)


func _resolve_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactResult:
	var source_snapshot := snapshot.get_unit_snapshot(impact.source_unit)

	if source_snapshot == null:
		return ImpactResult.create(
			impact,
			ImpactResult.Outcome.INVALID_SOURCE
		)

	var target_snapshot := snapshot.get_unit_snapshot(impact.target_unit)

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

	if impact.operation == Impact.Operation.HEAL:
		var blocking_effect := status_effect_system.blocks_healing_kind(
			impact.target_unit,
			impact.healing_kind
		)

		if blocking_effect != null:
			var blocked := ImpactResult.create(
				impact,
				ImpactResult.Outcome.BLOCKED_PASSIVE_RULE
			)
			blocked.blocking_effect_runtime = blocking_effect
			blocked.hp_before = target_snapshot.current_hp
			blocked.hp_after = target_snapshot.current_hp
			blocked.message = (
				"Healing kind '%s' is blocked by effect '%s'."
				% [
					Impact.get_healing_kind_id(impact.healing_kind),
					blocking_effect.get_effect_id()
				]
			)
			return blocked

	var result := ImpactResult.create(impact, ImpactResult.Outcome.APPLIED)
	result.hp_before = target_snapshot.current_hp

	var interaction_resolution := interaction_resolver.resolve(
		impact,
		target_snapshot,
		snapshot,
		battle_state.battle_rng
	)
	_apply_interaction_resolution(result, interaction_resolution)

	if not result.was_applied():
		result.hp_after = result.hp_before
		return result

	match impact.operation:
		Impact.Operation.HEAL:
			result.hp_after = min(
				target_snapshot.max_hp,
				target_snapshot.current_hp + impact.magnitude
			)
			result.magnitude_applied = result.hp_after - result.hp_before

		Impact.Operation.DAMAGE:
			result.hp_after = max(
				0,
				target_snapshot.current_hp - impact.magnitude
			)
			result.magnitude_applied = result.hp_before - result.hp_after

		Impact.Operation.APPLY_EFFECT:
			result.hp_after = result.hp_before

	return result


func _apply_interaction_resolution(
	impact_result : ImpactResult,
	resolution : InteractionResolution
) -> void:
	impact_result.interaction_resolution = resolution

	if resolution == null:
		impact_result.outcome = ImpactResult.Outcome.INVALID_INTERACTION
		impact_result.message = (
			"ImpactExecutor: InteractionResolver returned null"
		)
		return

	impact_result.effective_armor = resolution.effective_armor
	impact_result.block_chance = resolution.block_chance
	impact_result.armor_roll = resolution.armor_roll
	impact_result.consumed_defense = resolution.defense_to_consume
	impact_result.message = resolution.message

	match resolution.outcome:
		InteractionResolution.Outcome.ALLOWED:
			impact_result.outcome = ImpactResult.Outcome.APPLIED

		InteractionResolution.Outcome.BLOCKED_IMMUNITY:
			impact_result.outcome = ImpactResult.Outcome.BLOCKED_IMMUNITY

		InteractionResolution.Outcome.BLOCKED_DEFENSE:
			impact_result.outcome = ImpactResult.Outcome.BLOCKED_DEFENSE

		InteractionResolution.Outcome.BLOCKED_ARMOR:
			impact_result.outcome = ImpactResult.Outcome.BLOCKED_ARMOR

		InteractionResolution.Outcome.INVALID:
			impact_result.outcome = ImpactResult.Outcome.INVALID_INTERACTION


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

		match impact.operation:
			Impact.Operation.DAMAGE:
				target.take_damage(impact.magnitude)
				result.magnitude_applied = max(
					0,
					hp_before_apply - target.current_hp
				)

			Impact.Operation.HEAL:
				target.heal(impact.magnitude)
				result.magnitude_applied = max(
					0,
					target.current_hp - hp_before_apply
				)

			Impact.Operation.APPLY_EFFECT:
				result.effect_application_result = (
					status_effect_system.apply_effect(impact, battle_state)
				)

				if (
					result.effect_application_result == null
					or result.effect_application_result.status
					== EffectApplicationResult.Status.REJECTED
				):
					result.outcome = ImpactResult.Outcome.INVALID_EFFECT
					if result.effect_application_result != null:
						result.message = (
							result.effect_application_result.message
						)

		result.hp_before = hp_before_apply
		result.hp_after = target.current_hp

		var event : CombatEvent = null

		if combat_event_log != null:
			event = combat_event_log.record_impact_result(
				result,
				battle_state
			)

		if event != null and reaction_system != null:
			reaction_system.collect_reactions(event, battle_state)

		_print_result(result)


func _drain_reactions(
	battle_state : BattleState,
	root_result : ImpactPlanExecutionResult
) -> void:
	if reaction_queue == null or reaction_system == null:
		return

	_is_draining_reactions = true

	while reaction_queue.has_pending():
		var task := reaction_queue.pop_front()

		if task == null or task.reaction_depth > ReactionSystem.MAX_REACTION_DEPTH:
			continue

		var build_result := reaction_system.build_plan(task)

		if not build_result.is_valid or build_result.plan == null:
			var failed_build := ImpactPlanExecutionResult.new()
			failed_build.status = (
				ImpactPlanExecutionResult.Status.VALIDATION_FAILED
			)
			failed_build.issues.append(build_result.message)
			root_result.reaction_execution_results.append(failed_build)
			continue

		var reaction_snapshot := BattleStateSnapshot.capture(battle_state)
		var reaction_result := _execute_plan_core(
			build_result.plan,
			reaction_snapshot,
			battle_state
		)
		root_result.reaction_execution_results.append(reaction_result)

	_is_draining_reactions = false


func _validate_impact(
	impact : Impact,
	plan : ImpactPlan,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState,
	seen_ids : Dictionary,
	issues : PackedStringArray
) -> void:
	if impact == null:
		issues.append("ImpactExecutor: plan contains a null impact")
		return

	if impact.impact_id == &"":
		issues.append("ImpactExecutor: impact_id is empty")
	elif seen_ids.has(impact.impact_id):
		issues.append(
			"ImpactExecutor: duplicate impact_id '%s'" % impact.impact_id
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
	elif battle_state != null and not battle_state.units.has(impact.source_unit):
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
	elif battle_state != null and not battle_state.units.has(impact.target_unit):
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
			"ImpactExecutor: target cell of impact '%s' is absent from snapshot"
			% impact.impact_id
		)
	elif (
		impact.target_cell != null
		and battle_state != null
		and not battle_state.cells.has(impact.target_cell)
	):
		issues.append(
			"ImpactExecutor: target cell of impact '%s' is absent from battle"
			% impact.impact_id
		)

	if impact.operation not in [
		Impact.Operation.DAMAGE,
		Impact.Operation.HEAL,
		Impact.Operation.SUMMON,
		Impact.Operation.APPLY_EFFECT
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
		Impact.InteractionType.SUMMON,
		Impact.InteractionType.EFFECT
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

	if impact.operation == Impact.Operation.APPLY_EFFECT:
		if impact.interaction_type != Impact.InteractionType.EFFECT:
			issues.append(
				"ImpactExecutor: effect impact '%s' has incompatible interaction"
				% impact.impact_id
			)

		if impact.effect_data == null:
			issues.append(
				"ImpactExecutor: effect impact '%s' has no EffectData"
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

	if (
		impact.operation in [Impact.Operation.DAMAGE, Impact.Operation.HEAL]
		and impact.magnitude <= 0
	):
		issues.append(
			"ImpactExecutor: impact '%s' has non-positive magnitude"
			% impact.impact_id
		)

	if (
		impact.armor_penetration < InteractionResolver.MIN_ARMOR_PENETRATION
		or impact.armor_penetration > InteractionResolver.MAX_ARMOR_PENETRATION
	):
		issues.append(
			"ImpactExecutor: impact '%s' has armor penetration outside %d...%d"
			% [
				impact.impact_id,
				InteractionResolver.MIN_ARMOR_PENETRATION,
				InteractionResolver.MAX_ARMOR_PENETRATION
			]
		)

	if (
		impact.interaction_type == Impact.InteractionType.EFFECT
		and impact.armor_penetration != 0
	):
		issues.append(
			"ImpactExecutor: EFFECT impact '%s' must not use armor penetration"
			% impact.impact_id
		)

	if impact.operation == Impact.Operation.SUMMON:
		issues.append("ImpactExecutor: SUMMON is not implemented in this stage")

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
