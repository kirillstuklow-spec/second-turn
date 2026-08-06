extends SceneTree


const TEST_SEED : int = 20260806

const POISONING_DART_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/PoisoningDart.tres"
)
const DECAY_PATH : String = "res://Resources/Effects/Decay.tres"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_schema_direct_hit_and_decay_defense()
	_test_activation_end_resistance_duration_and_armor_bypass()
	_test_application_activation_and_duplicate_event_are_skipped()
	_test_decay_kill_ends_battle_before_next_activation()

	print(
		"PoisoningDartDecaySmokeTest: PASS — declarative Poisoning Dart, "
		+ "DECAY source migration, activation-end trigger, late defense, "
		+ "same-activation skip, two full carrier activations and victory"
	)

	quit()


func _test_resource_schema_direct_hit_and_decay_defense() -> void:
	var poisoning_dart := _load_poisoning_dart()
	var decay_data := _load_decay()
	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(poisoning_dart)

	assert(schema.is_valid, schema.get_summary())
	assert(poisoning_dart.impact_plan_data != null)
	assert(poisoning_dart.impact_plan_data.nodes.size() == 2)
	assert(poisoning_dart.impact_plan_data.nodes[0].source_type == "decay")
	assert(poisoning_dart.impact_plan_data.nodes[1].source_type == "decay")
	var apply_decay_condition : ImpactConditionData = (
		poisoning_dart.impact_plan_data.nodes[1].transition_condition
	)
	assert(
		apply_decay_condition.condition_type
		== ImpactConditionData.ConditionType.PARENT_MAGNITUDE_APPLIED_AT_LEAST
	)
	assert(decay_data.effect_id == "status.decay")
	assert(decay_data.triggers.size() == 1)
	assert(
		decay_data.triggers[0].event_kind
		== CombatEvent.Kind.ACTIVATION_ENDED
	)
	assert(decay_data.triggers[0].skip_application_activation)
	assert(
		decay_data.triggers[0].frequency_policy
		== EffectTriggerData.FrequencyPolicy.ONCE_PER_ACTIVATION
	)

	var bundle := _make_pipeline_battle(20)
	var pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var battle_state := bundle["battle_state"] as BattleState
	var combat_event_log := bundle["combat_event_log"] as CombatEventLog
	var hunter := bundle["hunter"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime
	var hp_before := target.current_hp
	var execution := pipeline.execute_ability(
		hunter,
		target,
		hunter.active_abilities[0],
		target.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(execution.get_impact_results().size() == 2)
	assert(execution.get_impact_results()[0].magnitude_applied == 3)
	var decay_application : EffectApplicationResult = (
		execution.get_impact_results()[1].effect_application_result
	)
	assert(
		decay_application.status
		== EffectApplicationResult.Status.APPLIED
	)
	assert(execution.impact_execution_result.reaction_execution_results.is_empty())
	assert(target.current_hp == hp_before - 3)

	var decay := target.get_active_effect(&"status.decay")
	assert(decay != null)
	assert(decay.source_unit == hunter)
	assert(decay.remaining_duration == 2)
	assert(decay.last_application_activation_serial == 1)
	assert(combat_event_log.history.size() == 2)
	assert(combat_event_log.history[0].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(combat_event_log.history[0].source_type == &"decay")
	assert(combat_event_log.history[0].activation_serial == 1)
	assert(combat_event_log.history[1].kind == CombatEvent.Kind.EFFECT_APPLIED)
	assert(battle_state.active_unit == hunter)

	_free_pipeline_bundle(bundle)

	# Защита от источника DECAY останавливает прямой Impact раньше брони.
	bundle = _make_pipeline_battle(20)
	pipeline = bundle["ability_pipeline"] as AbilityPipeline
	hunter = bundle["hunter"] as UnitRuntime
	target = bundle["target"] as UnitRuntime
	target.active_defenses.append("decay")
	hp_before = target.current_hp
	execution = pipeline.execute_ability(
		hunter,
		target,
		hunter.active_abilities[0],
		target.cell
	)

	assert(execution.was_committed())
	assert(target.current_hp == hp_before)
	assert(target.get_active_effect(&"status.decay") == null)
	assert(not target.active_defenses.has("decay"))
	assert(
		execution.get_impact_results()[0].outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		execution.get_impact_results()[1].outcome
		== ImpactResult.Outcome.SKIPPED_CONDITION
	)

	_free_pipeline_bundle(bundle)


func _test_activation_end_resistance_duration_and_armor_bypass() -> void:
	var bundle := _make_pipeline_battle(20)
	var pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var turn_pipeline := bundle["turn_pipeline"] as TurnPipeline
	var battle_state := bundle["battle_state"] as BattleState
	var combat_event_log := bundle["combat_event_log"] as CombatEventLog
	var hunter := bundle["hunter"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	assert(pipeline.execute_ability(
		hunter,
		target,
		hunter.active_abilities[0],
		target.cell
	).was_committed())

	var decay := target.get_active_effect(&"status.decay")
	assert(decay != null)
	target.active_defenses.append("effect")
	target.armor = 5

	# Окончание активации Охотницы не относится к носителю Разложения.
	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == target)
	assert(decay.remaining_duration == 2)

	# Первая полная активация носителя: защита блокирует тик и расходуется,
	# но время эффекта всё равно проходит.
	var hp_before_blocked_tick := target.current_hp
	turn_pipeline.end_current_activation()
	assert(target.current_hp == hp_before_blocked_tick)
	assert(not target.active_defenses.has("effect"))
	assert(target.get_active_effect(&"status.decay") == decay)
	assert(decay.remaining_duration == 1)

	# Следующий раунд: Охотница завершает активацию, затем цель. Броня 5
	# гарантированно остановила бы тик, если бы EFFECT проверял броню.
	assert(battle_state.active_unit == hunter)
	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == target)
	var hp_before_second_tick := target.current_hp
	turn_pipeline.end_current_activation()

	assert(target.current_hp == hp_before_second_tick - 1)
	assert(target.get_active_effect(&"status.decay") == null)
	assert(not battle_state.is_battle_over)

	var decay_damage_event : CombatEvent = null

	for event in combat_event_log.history:
		if (
			event != null
			and event.kind == CombatEvent.Kind.DAMAGE_APPLIED
			and event.source_type == &"decay"
			and event.origin_effect_runtime_id == decay.runtime_id
		):
			decay_damage_event = event

	assert(decay_damage_event != null)
	assert(decay_damage_event.target_unit == target)
	assert(decay_damage_event.applied_amount == 1)

	_free_pipeline_bundle(bundle)


func _test_application_activation_and_duplicate_event_are_skipped() -> void:
	var bundle := _make_pipeline_battle(20)
	var battle_state := bundle["battle_state"] as BattleState
	var executor := bundle["impact_executor"] as ImpactExecutor
	var status_effect_system := (
		bundle["status_effect_system"] as StatusEffectSystem
	)
	var hunter := bundle["hunter"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	battle_state.set_active_unit(target)
	battle_state.turn_state.activation_serial = 50
	target.start_activation(1, 1)
	assert(_execute_apply_decay(
		executor,
		battle_state,
		hunter,
		target,
		&"same_activation_apply"
	).is_successful())

	var decay := target.get_active_effect(&"status.decay")
	assert(decay != null)
	var hp_before_same_activation := target.current_hp
	var same_activation := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		target,
		battle_state
	)

	assert(same_activation.is_successful())
	assert(same_activation.reaction_execution_results.is_empty())
	assert(target.current_hp == hp_before_same_activation)
	status_effect_system.finish_activation(target, 50)
	assert(decay.remaining_duration == 2)

	# В следующей полной активации срабатывает ровно один раз, даже если
	# одинаковая граница по ошибке будет опубликована повторно.
	battle_state.turn_state.activation_serial = 51
	var first_event := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		target,
		battle_state
	)
	assert(first_event.reaction_execution_results.size() == 1)
	var hp_after_first_event := target.current_hp
	var duplicate_event := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		target,
		battle_state
	)
	assert(duplicate_event.reaction_execution_results.is_empty())
	assert(target.current_hp == hp_after_first_event)
	status_effect_system.finish_activation(target, 51)
	assert(decay.remaining_duration == 1)

	battle_state.turn_state.activation_serial = 52
	var final_event := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		target,
		battle_state
	)
	assert(final_event.reaction_execution_results.size() == 1)
	status_effect_system.finish_activation(target, 52)
	assert(target.get_active_effect(&"status.decay") == null)

	_free_pipeline_bundle(bundle)


func _test_decay_kill_ends_battle_before_next_activation() -> void:
	var bundle := _make_pipeline_battle(4)
	var pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var turn_pipeline := bundle["turn_pipeline"] as TurnPipeline
	var battle_state := bundle["battle_state"] as BattleState
	var combat_event_log := bundle["combat_event_log"] as CombatEventLog
	var hunter := bundle["hunter"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	assert(pipeline.execute_ability(
		hunter,
		target,
		hunter.active_abilities[0],
		target.cell
	).was_committed())
	assert(target.current_hp == 1)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == target)
	turn_pipeline.end_current_activation()

	assert(not target.is_alive)
	assert(target.current_hp == 0)
	assert(target.cell == null)
	assert(battle_state.is_battle_over)
	assert(battle_state.winner_team_id == 1)
	assert(battle_state.turn_state.phase == TurnState.Phase.BATTLE_END)
	assert(combat_event_log.history[-1].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(combat_event_log.history[-1].source_type == &"decay")
	assert(combat_event_log.history[-1].target_unit == target)

	_free_pipeline_bundle(bundle)


func _make_pipeline_battle(target_max_hp : int) -> Dictionary:
	var poisoning_dart := _load_poisoning_dart()
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()

	var hunter_data := _make_unit_data(
		"hunter",
		"Hunter",
		10,
		100
	)
	hunter_data.active_abilities.append(poisoning_dart)
	var target_data := _make_unit_data(
		"decay_target",
		"Decay Target",
		target_max_hp,
		0
	)
	var hunter := battle_state.spawn_unit(hunter_data, 1, 0, 2)
	var target := battle_state.spawn_unit(target_data, 2, 6, 2)
	assert(hunter != null)
	assert(target != null)

	var registry := AbilityAlgorithmRegistry.new()
	var availability := AbilityAvailabilityService.new(registry)
	var targeting := TargetingService.new()
	var builder := AbilityImpactPlanBuilder.new()
	var status_effect_system := StatusEffectSystem.new()
	var combat_event_log := CombatEventLog.new()
	var reaction_queue := ReactionQueue.new()
	var reaction_system := ReactionSystem.new()
	reaction_system.configure(reaction_queue, builder)
	var impact_executor := ImpactExecutor.new()
	impact_executor.configure(
		InteractionResolver.new(),
		status_effect_system,
		combat_event_log,
		reaction_queue,
		reaction_system,
		ImpactConditionEvaluator.new(),
		builder
	)

	var ability_pipeline := AbilityPipeline.new()
	var turn_pipeline := TurnPipeline.new()
	var event_queue := EventQueue.new()
	root.add_child(ability_pipeline)
	root.add_child(turn_pipeline)
	root.add_child(event_queue)
	ability_pipeline.configure(
		battle_state,
		availability,
		registry,
		targeting,
		builder,
		impact_executor
	)
	turn_pipeline.configure(
		battle_state,
		event_queue,
		status_effect_system,
		impact_executor
	)
	turn_pipeline.start_battle_flow()

	assert(battle_state.active_unit == hunter)

	return {
		"battle_state": battle_state,
		"hunter": hunter,
		"target": target,
		"ability_pipeline": ability_pipeline,
		"turn_pipeline": turn_pipeline,
		"event_queue": event_queue,
		"impact_executor": impact_executor,
		"status_effect_system": status_effect_system,
		"combat_event_log": combat_event_log
	}


func _execute_apply_decay(
	executor : ImpactExecutor,
	battle_state : BattleState,
	source : UnitRuntime,
	target : UnitRuntime,
	execution_id : StringName
) -> ImpactPlanExecutionResult:
	var impact := Impact.create(
		StringName("%s_apply_decay" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.APPLY_EFFECT,
		Impact.InteractionType.EFFECT,
		&"decay",
		0,
		0
	)
	impact.effect_data = _load_decay()
	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	return executor.execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)


func _make_unit_data(
	unit_id : String,
	unit_name : String,
	max_hp : int,
	initiative : int
) -> UnitData:
	var data := UnitData.new()
	data.unit_id = unit_id
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.armor = 0
	data.movement = 2
	data.initiative = initiative
	return data


func _load_poisoning_dart() -> UnitAbilityData:
	var poisoning_dart := load(POISONING_DART_PATH) as UnitAbilityData
	assert(poisoning_dart != null)
	return poisoning_dart


func _load_decay() -> EffectData:
	var decay_data := load(DECAY_PATH) as EffectData
	assert(decay_data != null)
	return decay_data


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	for key in ["ability_pipeline", "turn_pipeline", "event_queue"]:
		var node := bundle.get(key, null) as Node

		if node != null:
			node.free()
