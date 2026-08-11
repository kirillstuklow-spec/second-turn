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

var death_resolver : DeathResolver = DeathResolver.new()

var condition_evaluator : ImpactConditionEvaluator = (
	ImpactConditionEvaluator.new()
)

var _reaction_plan_builder : AbilityImpactPlanBuilder = (
	AbilityImpactPlanBuilder.new()
)

var _is_draining_reactions : bool = false

var _suspended_root_result : ImpactPlanExecutionResult = null


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
	new_reaction_plan_builder : AbilityImpactPlanBuilder = null,
	new_death_resolver : DeathResolver = null
) -> void:
	_is_draining_reactions = false
	_suspended_root_result = null
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

	if new_death_resolver != null:
		death_resolver = new_death_resolver

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

	if death_resolver == null:
		death_resolver = DeathResolver.new()

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
		_stabilize_reactions_and_deaths(battle_state, result)

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
	_stabilize_reactions_and_deaths(battle_state, result)
	return result


# Вызывается AbilityPipeline после окончательного commit HP-цены, но до
# исполнения основного ImpactPlan. Реакция ставится в общую очередь и будет
# стабилизирована после основного плана: поэтому «Прыжок» сначала перемещает
# Гуля, а затем Горение отвечает на уже совершённую трату здоровья.
func collect_health_point_cost_event(
	unit : UnitRuntime,
	ability_data : UnitAbilityData,
	execution_id : StringName,
	hp_before : int,
	hp_after : int,
	battle_state : BattleState
) -> CombatEvent:
	if combat_event_log == null or reaction_system == null:
		return null

	var event := combat_event_log.record_health_point_cost_event(
		unit,
		ability_data,
		execution_id,
		hp_before,
		hp_after,
		battle_state
	)

	if event != null:
		reaction_system.collect_reactions(event, battle_state)

	return event


func finish_battlefield_object_round(
	round_number : int,
	battle_state : BattleState
) -> void:
	if battle_state == null:
		return

	var objects_at_round_end : Array[BattlefieldObjectRuntime] = []
	objects_at_round_end.append_array(battle_state.battlefield_objects)

	for object_runtime in objects_at_round_end:
		if object_runtime != null and object_runtime.finish_round(round_number):
			_remove_battlefield_object(
				object_runtime,
				&"duration_expired",
				null,
				battle_state
			)


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

	if impact.operation == Impact.Operation.MOVE:
		return _resolve_move_impact(
			impact,
			snapshot,
			battle_state
		)

	if impact.operation == Impact.Operation.SUMMON:
		return _resolve_summon_impact(
			impact,
			snapshot,
			battle_state
		)

	if impact.operation == Impact.Operation.CREATE_OBJECT:
		return _resolve_create_object_impact(
			impact,
			snapshot,
			battle_state
		)

	if impact.operation == Impact.Operation.AFFECT_CELL:
		return _resolve_affect_cell_impact(
			impact,
			snapshot
		)

	var target_snapshot := snapshot.get_unit_snapshot(impact.target_unit)

	if target_snapshot == null or not target_snapshot.is_alive:
		return ImpactResult.create(
			impact,
			ImpactResult.Outcome.INVALID_TARGET
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
			result.hp_after = clampi(
				target_snapshot.current_hp + impact.magnitude,
				0,
				target_snapshot.max_hp
			)
			result.magnitude_applied = abs(
				result.hp_after - result.hp_before
			)

		Impact.Operation.DAMAGE:
			result.hp_after = max(
				0,
				target_snapshot.current_hp - impact.magnitude
			)
			result.magnitude_applied = result.hp_before - result.hp_after

		Impact.Operation.APPLY_EFFECT:
			result.hp_after = result.hp_before

	return result


func _resolve_move_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactResult:
	var result := ImpactResult.create(
		impact,
		ImpactResult.Outcome.APPLIED
	)
	var target_snapshot := snapshot.get_unit_snapshot(impact.target_unit)

	if target_snapshot == null or not target_snapshot.is_alive:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Movement target is not a living battle unit."
		return result

	var destination_snapshot := snapshot.get_cell_snapshot(
		impact.target_cell
	)

	if destination_snapshot == null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Movement destination is absent from snapshot."
		return result

	if destination_snapshot.occupying_unit != null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Movement destination was occupied at commit."
		return result

	if (
		battle_state == null
		or not battle_state.can_unit_move_to(
			impact.target_unit,
			impact.target_cell,
			impact.movement_max_distance
		)
	):
		result.outcome = ImpactResult.Outcome.MOVE_FAILED
		result.message = "BattleState rejected movement rules."
		return result

	result.movement_from_cell = target_snapshot.cell
	result.movement_to_cell = impact.target_cell
	result.magnitude_applied = (
		abs(target_snapshot.cell_x - destination_snapshot.x)
		+ abs(target_snapshot.cell_y - destination_snapshot.y)
	)
	return result


func _resolve_summon_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactResult:
	var result := ImpactResult.create(
		impact,
		ImpactResult.Outcome.APPLIED
	)
	result.magnitude_requested = 1

	if impact.summon_unit_data == null:
		result.outcome = ImpactResult.Outcome.SUMMON_FAILED
		result.message = "Summon UnitData is missing."
		return result

	var cell_snapshot := snapshot.get_cell_snapshot(impact.target_cell)

	if cell_snapshot == null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Summon target cell is absent from snapshot."
		return result

	if cell_snapshot.occupying_unit != null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Summon target cell was occupied at commit."
		return result

	if (
		battle_state == null
		or impact.target_cell == null
		or impact.target_cell.is_occupied()
	):
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Summon target cell is no longer free."
		return result

	# Один Impact всегда создаёт один runtime-экземпляр. Фактическая ссылка
	# появится в _apply_summon_result().
	result.magnitude_applied = 1
	return result


func _resolve_create_object_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot,
	battle_state : BattleState
) -> ImpactResult:
	var result := ImpactResult.create(
		impact,
		ImpactResult.Outcome.APPLIED
	)
	result.magnitude_requested = 1

	if impact.battlefield_object_data == null:
		result.outcome = ImpactResult.Outcome.OBJECT_CREATION_FAILED
		result.message = "BattlefieldObjectData is missing."
		return result

	var anchor_snapshot := snapshot.get_cell_snapshot(
		impact.target_cell
	)

	if anchor_snapshot == null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Object anchor cell is absent from snapshot."
		return result

	if battle_state == null:
		result.outcome = ImpactResult.Outcome.OBJECT_CREATION_FAILED
		result.message = "BattleState is unavailable for object creation."
		return result

	result.object_covered_cells = (
		battle_state.get_battlefield_object_coverage(
			impact.battlefield_object_data,
			impact.target_cell
		)
	)

	if (
		result.object_covered_cells.size()
		!= impact.battlefield_object_data.coverage_offsets.size()
	):
		result.outcome = ImpactResult.Outcome.OBJECT_CREATION_FAILED
		result.object_covered_cells.clear()
		result.message = "Object coverage is outside battlefield."
		return result

	result.magnitude_applied = 1
	return result


func _resolve_affect_cell_impact(
	impact : Impact,
	snapshot : BattleStateSnapshot
) -> ImpactResult:
	var result := ImpactResult.create(
		impact,
		ImpactResult.Outcome.APPLIED
	)
	result.magnitude_requested = 1

	if snapshot.get_cell_snapshot(impact.target_cell) == null:
		result.outcome = ImpactResult.Outcome.INVALID_TARGET
		result.message = "Affected cell is absent from snapshot."
		return result

	result.magnitude_applied = 1
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

		if impact.operation == Impact.Operation.SUMMON:
			_apply_summon_result(result, battle_state)
			continue

		if impact.operation == Impact.Operation.MOVE:
			_apply_move_result(result, battle_state)
			continue

		if impact.operation == Impact.Operation.CREATE_OBJECT:
			_apply_create_object_result(result, battle_state)
			continue

		if impact.operation == Impact.Operation.AFFECT_CELL:
			_apply_affect_cell_result(result, battle_state)
			continue

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
				if impact.magnitude > 0:
					target.heal(impact.magnitude)
				else:
					target.take_damage(abs(impact.magnitude))

				result.magnitude_applied = abs(
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
		var health_loss_event : CombatEvent = null

		if combat_event_log != null:
			event = combat_event_log.record_impact_result(
				result,
				battle_state
			)
			health_loss_event = (
				combat_event_log.record_health_loss_from_impact_result(
					result,
					event,
					battle_state
				)
			)

		if event != null and death_resolver != null:
			death_resolver.observe_combat_event(event)

		if event != null and reaction_system != null:
			reaction_system.collect_reactions(event, battle_state)

		if health_loss_event != null and reaction_system != null:
			reaction_system.collect_reactions(
				health_loss_event,
				battle_state
			)

		_record_spatial_impact_event(result, battle_state)

		_print_result(result)


func _apply_summon_result(
	result : ImpactResult,
	battle_state : BattleState
) -> void:
	if result == null or result.impact == null:
		return

	if not result.was_applied():
		_print_result(result)
		return

	var impact := result.impact
	result.magnitude_applied = 0
	var summoned_unit := battle_state.summon_unit(
		impact.summon_unit_data,
		impact.source_unit,
		impact.source_ability_data,
		impact.execution_id,
		impact.target_cell
	)

	if summoned_unit == null:
		result.outcome = ImpactResult.Outcome.SUMMON_FAILED
		result.message = "BattleState rejected the summon."
		_print_result(result)
		return

	result.summoned_unit = summoned_unit
	result.magnitude_applied = 1

	var event : CombatEvent = null

	if combat_event_log != null:
		event = combat_event_log.record_impact_result(
			result,
			battle_state
		)

	if event != null and reaction_system != null:
		reaction_system.collect_reactions(event, battle_state)

	_print_result(result)


func _apply_move_result(
	result : ImpactResult,
	battle_state : BattleState
) -> void:
	if result == null or result.impact == null:
		return

	if not result.was_applied():
		_print_result(result)
		return

	var impact := result.impact
	var moved := battle_state.move_unit(
		impact.target_unit,
		impact.target_cell,
		impact.movement_max_distance
	)

	if not moved:
		result.outcome = ImpactResult.Outcome.MOVE_FAILED
		result.magnitude_applied = 0
		result.message = "BattleState could not apply movement."
		_print_result(result)
		return

	result.movement_to_cell = impact.target_unit.cell

	var event : CombatEvent = null

	if combat_event_log != null:
		event = combat_event_log.record_impact_result(
			result,
			battle_state
		)

	if event != null and reaction_system != null:
		reaction_system.collect_reactions(event, battle_state)

	_print_result(result)


func _apply_create_object_result(
	result : ImpactResult,
	battle_state : BattleState
) -> void:
	if result == null or result.impact == null:
		return

	if not result.was_applied():
		_print_result(result)
		return

	var impact := result.impact
	var object_runtime := battle_state.create_battlefield_object(
		impact.battlefield_object_data,
		impact.source_unit,
		impact.source_ability_data,
		impact.execution_id,
		impact.target_cell
	)

	if object_runtime == null:
		result.outcome = ImpactResult.Outcome.OBJECT_CREATION_FAILED
		result.magnitude_applied = 0
		result.message = "BattleState rejected battlefield object creation."
		_print_result(result)
		return

	result.created_battlefield_object = object_runtime
	result.object_covered_cells.clear()
	result.object_covered_cells.append_array(object_runtime.covered_cells)
	result.magnitude_applied = 1

	var event : CombatEvent = null

	if combat_event_log != null:
		event = combat_event_log.record_impact_result(
			result,
			battle_state
		)

	if event != null and reaction_system != null:
		reaction_system.collect_reactions(event, battle_state)

	_print_result(result)


func _record_spatial_impact_event(
	result : ImpactResult,
	battle_state : BattleState
) -> void:
	if combat_event_log == null or reaction_system == null:
		return

	var event := combat_event_log.record_spatial_impact_event(
		result,
		battle_state
	)

	if event != null:
		reaction_system.collect_reactions(event, battle_state)


func _apply_affect_cell_result(
	result : ImpactResult,
	battle_state : BattleState
) -> void:
	if result == null or result.impact == null:
		return

	if result.was_applied():
		_record_spatial_impact_event(result, battle_state)

	_print_result(result)


func _stabilize_reactions_and_deaths(
	battle_state : BattleState,
	root_result : ImpactPlanExecutionResult
) -> void:
	if (
		battle_state == null
		or root_result == null
		or reaction_queue == null
		or reaction_system == null
		or death_resolver == null
	):
		return

	_is_draining_reactions = true

	while true:
		while reaction_queue.has_pending():
			var task := reaction_queue.pop_front()

			if (
				task == null
				or task.reaction_depth > ReactionSystem.MAX_REACTION_DEPTH
			):
				continue

			if reaction_system.requires_target_decision(task):
				var decision := reaction_system.create_pending_decision(
					task,
					battle_state
				)

				if decision == null or decision.options.is_empty():
					print(
						"Reaction skipped: no valid target for ",
						task.source_ability_data.ability_name
					)
					continue

				if not battle_state.set_pending_decision(decision):
					var failed_decision := ImpactPlanExecutionResult.new()
					failed_decision.status = (
						ImpactPlanExecutionResult.Status.INTERNAL_ERROR
					)
					failed_decision.issues.append(
						"ImpactExecutor: pending decision could not be stored"
					)
					root_result.reaction_execution_results.append(
						failed_decision
					)
					continue

				root_result.pending_decision = decision
				_suspended_root_result = root_result
				_is_draining_reactions = false
				return

			_execute_reaction_task(
				task,
				battle_state,
				root_result
			)

		var death_events := death_resolver.confirm_pending_deaths(
			battle_state,
			combat_event_log,
			status_effect_system
		)

		if death_events.is_empty():
			break

		for death_event in death_events:
			reaction_system.collect_reactions(
				death_event,
				battle_state
			)

	root_result.pending_decision = null
	_suspended_root_result = null
	_is_draining_reactions = false


func resolve_pending_decision(
	decision_id : StringName,
	target_unit : UnitRuntime,
	battle_state : BattleState
) -> DecisionResolutionResult:
	if battle_state == null or battle_state.pending_decision == null:
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.REJECTED_NO_DECISION,
			"Нет ожидающего решения."
		)

	var decision := battle_state.pending_decision

	if decision.decision_id != decision_id:
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.REJECTED_ID,
			"Идентификатор решения не совпадает."
		)

	if not reaction_system.select_pending_decision_target(
		decision,
		target_unit,
		battle_state
	):
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.REJECTED_OPTION,
			"Выбранная цель больше не является допустимой."
		)

	if _suspended_root_result == null:
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.FAILED_EXECUTION,
			"Продолжаемая цепочка воздействий не найдена."
		)

	var root_result := _suspended_root_result
	var reaction_task := decision.reaction_task
	battle_state.clear_pending_decision()
	root_result.pending_decision = null

	if not _execute_reaction_task(
		reaction_task,
		battle_state,
		root_result
	):
		_suspended_root_result = null
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.FAILED_EXECUTION,
			"Не удалось исполнить выбранную реакцию."
		)

	_stabilize_reactions_and_deaths(
		battle_state,
		root_result
	)

	return DecisionResolutionResult.resolved(
		target_unit,
		root_result
	)


func _execute_reaction_task(
	task : ReactionTask,
	battle_state : BattleState,
	root_result : ImpactPlanExecutionResult
) -> bool:
	if (
		task != null
		and task.source_battlefield_object != null
		and task.selected_targets.is_empty()
	):
		if task.consume_source_battlefield_object:
			_remove_battlefield_object(
				task.source_battlefield_object,
				&"trigger_consumed",
				task.trigger_event,
				battle_state
			)

		return true

	var build_result := reaction_system.build_plan(task)

	if not build_result.is_valid or build_result.plan == null:
		var failed_build := ImpactPlanExecutionResult.new()
		failed_build.status = (
			ImpactPlanExecutionResult.Status.VALIDATION_FAILED
		)
		failed_build.issues.append(build_result.message)
		root_result.reaction_execution_results.append(failed_build)

		if (
			task != null
			and task.source_battlefield_object != null
			and task.consume_source_battlefield_object
		):
			_remove_battlefield_object(
				task.source_battlefield_object,
				&"trigger_failed",
				task.trigger_event,
				battle_state
			)

		return false

	var reaction_snapshot := BattleStateSnapshot.capture(battle_state)
	var reaction_result := _execute_plan_core(
		build_result.plan,
		reaction_snapshot,
		battle_state
	)
	root_result.reaction_execution_results.append(reaction_result)

	if (
		task.source_battlefield_object != null
		and task.consume_source_battlefield_object
	):
		_remove_battlefield_object(
			task.source_battlefield_object,
			&"trigger_consumed",
			task.trigger_event,
			battle_state
		)

	return reaction_result.is_successful()


func _remove_battlefield_object(
	object_runtime : BattlefieldObjectRuntime,
	reason : StringName,
	cause_event : CombatEvent,
	battle_state : BattleState
) -> bool:
	if (
		object_runtime == null
		or battle_state == null
		or not battle_state.battlefield_objects.has(object_runtime)
	):
		return false

	if combat_event_log != null:
		combat_event_log.record_battlefield_object_removed_event(
			object_runtime,
			reason,
			cause_event,
			battle_state
		)

	if not battle_state.remove_battlefield_object(object_runtime):
		return false

	print(
		"BATTLEFIELD_OBJECT_REMOVED | runtime: ",
		object_runtime.runtime_id,
		" | object_id: ",
		object_runtime.get_object_id(),
		" | reason: ",
		reason
	)

	return true


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

	if impact.operation in [
		Impact.Operation.SUMMON,
		Impact.Operation.CREATE_OBJECT,
		Impact.Operation.AFFECT_CELL
	]:
		if impact.target_unit != null:
			issues.append(
				"ImpactExecutor: cell impact '%s' must not target a unit"
				% impact.impact_id
			)
	else:
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
		impact.operation == Impact.Operation.DAMAGE
		and impact.source_unit != null
		and impact.target_unit != null
		and impact.source_unit.team_id == impact.target_unit.team_id
		and not (impact.source_object is BattlefieldObjectRuntime)
	):
		issues.append(
			"ImpactExecutor: ordinary damage impact '%s' cannot target an ally"
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

	if impact.operation == Impact.Operation.SUMMON:
		if impact.target_cell == null:
			issues.append(
				"ImpactExecutor: summon impact '%s' has no target cell"
				% impact.impact_id
			)
		else:
			var summon_cell_snapshot := (
				snapshot.get_cell_snapshot(impact.target_cell)
				if snapshot != null
				else null
			)

			if (
				summon_cell_snapshot != null
				and summon_cell_snapshot.occupying_unit != null
			):
				issues.append(
					"ImpactExecutor: summon target cell of impact '%s' is occupied"
					% impact.impact_id
				)

		if impact.summon_unit_data == null:
			issues.append(
				"ImpactExecutor: summon impact '%s' has no UnitData"
				% impact.impact_id
			)

		if impact.source_ability_data == null:
			issues.append(
				"ImpactExecutor: summon impact '%s' has no source ability"
				% impact.impact_id
			)

		if impact.magnitude != 1:
			issues.append(
				"ImpactExecutor: summon impact '%s' must create exactly one unit"
				% impact.impact_id
			)

	if impact.operation == Impact.Operation.MOVE:
		if impact.target_cell == null:
			issues.append(
				"ImpactExecutor: move impact '%s' has no destination cell"
				% impact.impact_id
			)
		else:
			var move_cell_snapshot := (
				snapshot.get_cell_snapshot(impact.target_cell)
				if snapshot != null
				else null
			)

			if (
				move_cell_snapshot != null
				and move_cell_snapshot.occupying_unit != null
			):
				issues.append(
					"ImpactExecutor: move destination of impact '%s' is occupied"
					% impact.impact_id
				)

		if impact.movement_max_distance <= 0:
			issues.append(
				"ImpactExecutor: move impact '%s' has invalid distance"
				% impact.impact_id
			)

		if impact.magnitude != 1:
			issues.append(
				"ImpactExecutor: move impact '%s' must move one unit"
				% impact.impact_id
			)

	if impact.operation == Impact.Operation.CREATE_OBJECT:
		if impact.target_cell == null:
			issues.append(
				"ImpactExecutor: object impact '%s' has no anchor cell"
				% impact.impact_id
			)

		if impact.battlefield_object_data == null:
			issues.append(
				"ImpactExecutor: object impact '%s' has no BattlefieldObjectData"
				% impact.impact_id
			)
		else:
			for object_issue in (
				impact.battlefield_object_data.get_validation_issues()
			):
				issues.append(
					"ImpactExecutor: object impact '%s': %s"
					% [impact.impact_id, object_issue]
				)

		if impact.source_ability_data == null:
			issues.append(
				"ImpactExecutor: object impact '%s' has no source ability"
				% impact.impact_id
			)

		if impact.magnitude != 1:
			issues.append(
				"ImpactExecutor: object impact '%s' must create one object"
				% impact.impact_id
			)

	if impact.operation == Impact.Operation.AFFECT_CELL:
		if impact.target_cell == null:
			issues.append(
				"ImpactExecutor: cell impact '%s' has no target cell"
				% impact.impact_id
			)

		if impact.source_type == &"":
			issues.append(
				"ImpactExecutor: cell impact '%s' has no source type"
				% impact.impact_id
			)

		if impact.magnitude != 1:
			issues.append(
				"ImpactExecutor: cell impact '%s' must affect one cell"
				% impact.impact_id
			)

	if impact.operation not in [
		Impact.Operation.DAMAGE,
		Impact.Operation.HEAL,
		Impact.Operation.SUMMON,
		Impact.Operation.APPLY_EFFECT,
		Impact.Operation.MOVE,
		Impact.Operation.CREATE_OBJECT,
		Impact.Operation.AFFECT_CELL
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
		Impact.InteractionType.EFFECT,
		Impact.InteractionType.MOVEMENT,
		Impact.InteractionType.OBJECT,
		Impact.InteractionType.CELL
	]:
		issues.append(
			"ImpactExecutor: impact '%s' has invalid interaction type"
			% impact.impact_id
		)

	if (
		impact.operation == Impact.Operation.DAMAGE
		and impact.interaction_type in [
			Impact.InteractionType.HEALING,
			Impact.InteractionType.SUMMON,
			Impact.InteractionType.MOVEMENT,
			Impact.InteractionType.OBJECT,
			Impact.InteractionType.CELL
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
		impact.operation == Impact.Operation.MOVE
		and impact.interaction_type != Impact.InteractionType.MOVEMENT
	):
		issues.append(
			"ImpactExecutor: move impact '%s' has incompatible interaction"
			% impact.impact_id
		)

	if (
		impact.operation == Impact.Operation.CREATE_OBJECT
		and impact.interaction_type != Impact.InteractionType.OBJECT
	):
		issues.append(
			"ImpactExecutor: object impact '%s' has incompatible interaction"
			% impact.impact_id
		)

	if (
		impact.operation == Impact.Operation.AFFECT_CELL
		and impact.interaction_type != Impact.InteractionType.CELL
	):
		issues.append(
			"ImpactExecutor: cell impact '%s' has incompatible interaction"
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

	if impact.operation == Impact.Operation.DAMAGE and impact.magnitude <= 0:
		issues.append(
			"ImpactExecutor: damage impact '%s' has non-positive magnitude"
			% impact.impact_id
		)

	if impact.operation == Impact.Operation.HEAL and impact.magnitude == 0:
		issues.append(
			"ImpactExecutor: healing impact '%s' has zero magnitude"
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
		impact.interaction_type in [
			Impact.InteractionType.EFFECT,
			Impact.InteractionType.MOVEMENT,
			Impact.InteractionType.OBJECT,
			Impact.InteractionType.CELL
		]
		and impact.armor_penetration != 0
	):
		issues.append(
			"ImpactExecutor: non-armor impact '%s' must not use armor penetration"
			% impact.impact_id
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
