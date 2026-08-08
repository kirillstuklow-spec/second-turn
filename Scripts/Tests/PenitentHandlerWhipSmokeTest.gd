extends SceneTree


const TEST_SEED : int = 20260809

const HANDLER_PATH : String = (
	"res://Resources/Unit/PenitentHandlerData.tres"
)
const PENITENT_PATH : String = (
	"res://Resources/Unit/PenitentData.tres"
)
const WHIP_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/Whip.tres"
)
const WHIP_EFFECT_PATH : String = (
	"res://Resources/Effects/WhipDriven.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract()
	_test_adjacent_ally_targeting_and_blocked_hit()
	_test_round_lifetime_initiative_and_movement()
	_test_last_stand_prevents_one_death_before_last_step()

	print(
		"PenitentHandlerWhipSmokeTest: PASS — adjacent-ally SUPPORT "
		+ "targeting, MELEE + PHYSICAL damage gate, refreshable Подгон, "
		+ "+10 next-round initiative, +1 movement, round lifetime, "
		+ "one-use DEATH_PENDING prevention, DEATH_PREVENTED event and "
		+ "Last Step only after the following confirmed death"
	)
	quit()


# ============================================================
# РЕСУРСНЫЙ КОНТРАКТ
# ============================================================

func _test_resource_contract() -> void:
	var handler_data := load(HANDLER_PATH) as UnitData
	var whip := load(WHIP_PATH) as UnitAbilityData
	var effect := load(WHIP_EFFECT_PATH) as EffectData
	assert(handler_data != null)
	assert(whip != null)
	assert(effect != null)
	assert(handler_data.active_abilities.size() == 2)
	assert(handler_data.active_abilities[1] == whip)
	assert(whip.action_point_cost == 1)
	assert(whip.ability != null)
	assert(whip.ability.activation_mode == AbilityData.ActivationMode.ACTIVE)
	assert(whip.ability.action_type == AbilityData.ActionType.SUPPORT)
	assert(whip.ability.targeting_form == AbilityData.TargetingForm.MELEE)
	assert(whip.ability.algorithm_id == "execute_impact_plan")
	assert(whip.ability.target_rule_id == "single_adjacent_ally")
	assert(whip.impact_plan_data != null)
	assert(whip.impact_plan_data.nodes.size() == 2)

	var damage_node := whip.impact_plan_data.nodes[0]
	var effect_node := whip.impact_plan_data.nodes[1]
	assert(damage_node.node_id == "whip_damage")
	assert(damage_node.operation == Impact.Operation.DAMAGE)
	assert(damage_node.interaction_type == Impact.InteractionType.MELEE)
	assert(damage_node.source_type == "physical")
	assert(damage_node.magnitude == 1)
	assert(damage_node.armor_penetration == 0)
	assert(effect_node.parent_node_id == damage_node.node_id)
	assert(effect_node.operation == Impact.Operation.APPLY_EFFECT)
	assert(effect_node.interaction_type == Impact.InteractionType.EFFECT)
	assert(effect_node.effect_data == effect)

	assert(effect.effect_id == "status.whip_driven")
	assert(effect.reapply_policy == EffectData.ReapplyPolicy.REFRESH)
	assert(effect.duration != null)
	assert(
		effect.duration.duration_unit
		== EffectDurationData.DurationUnit.ROUNDS
	)
	assert(effect.duration.amount == 1)
	assert(effect.duration.skip_application_round)
	assert(effect.passive_rules.size() == 3)
	var initiative_rule := _get_rule(
		effect,
		PassiveRuleData.RuleType.MODIFY_INITIATIVE
	)
	var movement_rule := _get_rule(
		effect,
		PassiveRuleData.RuleType.MODIFY_MOVEMENT
	)
	var last_stand_rule := _get_rule(
		effect,
		PassiveRuleData.RuleType.PREVENT_DEATH
	)
	assert(initiative_rule != null)
	assert(movement_rule != null)
	assert(last_stand_rule != null)
	assert(initiative_rule.modifier_amount == 10)
	assert(movement_rule.modifier_amount == 1)
	assert(last_stand_rule.restored_hp == 1)

	var schema := AbilityAlgorithmRegistry.new().validate_unit_ability(whip)
	assert(schema.is_valid, schema.get_summary())


# ============================================================
# ЦЕЛЬ И ЗАВИСИМОСТЬ ЭФФЕКТА ОТ ПОПАДАНИЯ
# ============================================================

func _test_adjacent_ally_targeting_and_blocked_hit() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		1,
		0,
		2
	)
	var ally := battle_state.spawn_unit(
		_make_unit_data("whip_ally", "Whip Ally", 10, 25),
		1,
		1,
		2
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("whip_enemy", "Whip Enemy", 10, 15),
		2,
		0,
		1
	)
	var far_ally := battle_state.spawn_unit(
		_make_unit_data("far_ally", "Far Ally", 10, 5),
		1,
		3,
		2
	)
	assert(handler != null)
	assert(ally != null)
	assert(enemy != null)
	assert(far_ally != null)
	battle_state.set_active_unit(handler)
	handler.start_round(1)
	handler.start_activation(1, 0)

	var bundle := _make_pipeline_bundle(battle_state)
	var registry := bundle["algorithm_registry"] as AbilityAlgorithmRegistry
	var targeting := bundle["targeting_service"] as TargetingService
	var whip_runtime := handler.active_abilities[1]
	var schema := registry.validate_unit_ability(whip_runtime.data)
	assert(schema.is_valid, schema.get_summary())

	var valid_cells := targeting.get_valid_selection_cells(
		battle_state,
		handler,
		whip_runtime.data,
		schema.resolved_parameters
	)
	assert(valid_cells.size() == 1)
	assert(valid_cells.has(ally.cell))
	assert(not valid_cells.has(handler.cell))
	assert(not valid_cells.has(enemy.cell))
	assert(not valid_cells.has(far_ally.cell))

	var enemy_target := targeting.resolve(
		battle_state,
		handler,
		enemy,
		enemy.cell,
		whip_runtime.data,
		schema.resolved_parameters
	)
	assert(not enemy_target.is_valid)
	assert(enemy_target.reason == TargetingResult.Reason.TARGET_NOT_ALLY)

	ally.active_defenses.append("physical")
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		handler,
		ally,
		whip_runtime,
		ally.cell
	)
	assert(execution.was_committed(), execution.message)
	assert(handler.action_points_remaining == 0)
	assert(ally.current_hp == ally.data.max_hp)
	assert(not ally.active_defenses.has("physical"))
	assert(ally.get_active_effect(&"status.whip_driven") == null)
	assert(execution.get_impact_results().size() == 2)
	assert(
		execution.get_impact_results()[0].outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		execution.get_impact_results()[1].outcome
		== ImpactResult.Outcome.SKIPPED_PARENT
	)

	_free_pipeline_bundle(bundle)


# ============================================================
# ДЛИТЕЛЬНОСТЬ, ИНИЦИАТИВА И ДВИЖЕНИЕ
# ============================================================

func _test_round_lifetime_initiative_and_movement() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		1,
		0,
		2
	)
	var ally := battle_state.spawn_unit(
		_make_unit_data("driven_ally", "Driven Ally", 10, 45),
		1,
		1,
		2
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("round_enemy", "Round Enemy", 10, 5),
		2,
		6,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var turn_pipeline := bundle["turn_pipeline"] as TurnPipeline
	var ability_pipeline := bundle["ability_pipeline"] as AbilityPipeline
	turn_pipeline.start_battle_flow()
	assert(battle_state.round_number == 1)
	assert(battle_state.active_unit == ally)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == handler)
	var hp_before := ally.current_hp
	var execution := ability_pipeline.execute_ability(
		handler,
		ally,
		handler.active_abilities[1],
		ally.cell
	)
	assert(execution.was_committed(), execution.message)
	assert(ally.current_hp == hp_before - 1)
	var driven := ally.get_active_effect(&"status.whip_driven")
	assert(driven != null)
	assert(driven.remaining_duration == 1)
	assert(driven.last_application_round == 1)
	assert(execution.get_impact_results()[0].magnitude_applied == 1)
	assert(execution.get_impact_results()[1].was_applied())

	# Результат наложения не складывается вторым экземпляром, а обновляет тот же.
	var effect_system := bundle["status_effect_system"] as StatusEffectSystem
	var refresh_impact := _make_effect_impact(
		&"manual_refresh",
		handler,
		ally,
		load(WHIP_EFFECT_PATH) as EffectData,
		handler.active_abilities[1].data
	)
	var refresh_result := effect_system.apply_effect(refresh_impact, battle_state)
	assert(refresh_result.status == EffectApplicationResult.Status.REFRESHED)
	assert(ally.active_effects.size() == 1)
	assert(ally.active_effects[0] == driven)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == enemy)
	turn_pipeline.end_current_activation()
	assert(battle_state.round_number == 2)
	assert(battle_state.active_unit == ally)
	assert(ally.get_active_effect(&"status.whip_driven") == driven)
	assert(ally.initiative_effect_modifier_this_round == 10)
	assert(
		ally.initiative_roll_this_round
		== ally.data.initiative
		+ ally.initiative_modifier_this_round
		+ 10
	)
	assert(ally.movement_modifier_this_activation == 1)
	assert(ally.movement_points_remaining == ally.data.movement + 1)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == handler)
	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == enemy)
	turn_pipeline.end_current_activation()
	assert(battle_state.round_number == 3)
	assert(battle_state.active_unit == ally)
	assert(ally.get_active_effect(&"status.whip_driven") == null)
	assert(ally.initiative_effect_modifier_this_round == 0)
	assert(ally.movement_modifier_this_activation == 0)
	assert(ally.movement_points_remaining == ally.data.movement)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 2)
	assert(event_log.history[0].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[1].kind == CombatEvent.Kind.EFFECT_APPLIED)

	_free_pipeline_bundle(bundle)


# ============================================================
# «ПОСЛЕДНИЙ РУБЕЖ» И ПОСЛЕДУЮЩАЯ ПОДТВЕРЖДЁННАЯ СМЕРТЬ
# ============================================================

func _test_last_stand_prevents_one_death_before_last_step() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		1,
		0,
		2
	)
	var penitent := battle_state.spawn_unit(
		load(PENITENT_PATH) as UnitData,
		1,
		1,
		2
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("last_stand_enemy", "Last Stand Enemy", 10, 15),
		2,
		2,
		2
	)
	assert(handler != null)
	assert(penitent != null)
	assert(enemy != null)
	battle_state.set_active_unit(handler)
	handler.start_round(1)
	handler.start_activation(1, 0)
	penitent.start_round(1)
	enemy.start_round(1)

	var bundle := _make_pipeline_bundle(battle_state)
	var whip_execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		handler,
		penitent,
		handler.active_abilities[1],
		penitent.cell
	)
	assert(whip_execution.was_committed(), whip_execution.message)
	assert(penitent.current_hp == 3)
	assert(penitent.get_active_effect(&"status.whip_driven") != null)

	var executor := bundle["impact_executor"] as ImpactExecutor
	var first_lethal := _execute_damage_plan(
		executor,
		battle_state,
		&"first_lethal_execution",
		enemy,
		penitent,
		5
	)
	assert(first_lethal.is_successful())
	assert(penitent.is_alive)
	assert(penitent.death_state == UnitRuntime.DeathState.ALIVE)
	assert(penitent.current_hp == 1)
	assert(penitent.cell == battle_state.get_cell_at(1, 2))
	assert(penitent.get_active_effect(&"status.whip_driven") == null)
	assert(battle_state.pending_decision == null)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 4)
	assert(event_log.history[2].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[3].kind == CombatEvent.Kind.DEATH_PREVENTED)
	assert(event_log.history[3].source_unit == handler)
	assert(event_log.history[3].target_unit == penitent)
	assert(event_log.history[3].effect_id == &"status.whip_driven")
	assert(event_log.history[3].applied_amount == 1)
	assert(event_log.history[3].cause_event_id == event_log.history[2].event_id)
	assert(not _has_event_kind(event_log, CombatEvent.Kind.DEATH_CONFIRMED))

	var second_lethal := _execute_damage_plan(
		executor,
		battle_state,
		&"second_lethal_execution",
		enemy,
		penitent,
		2
	)
	assert(second_lethal.is_successful())
	assert(penitent.is_dead())
	assert(penitent.cell == null)
	assert(battle_state.pending_decision != null)
	assert(battle_state.pending_decision.options.has(enemy))
	assert(_has_event_kind(event_log, CombatEvent.Kind.DEATH_CONFIRMED))

	var enemy_hp_before := enemy.current_hp
	var decision_result := executor.resolve_pending_decision(
		battle_state.pending_decision.decision_id,
		enemy,
		battle_state
	)
	assert(decision_result.was_resolved(), decision_result.message)
	assert(enemy.current_hp == enemy_hp_before - 2)
	assert(battle_state.pending_decision == null)

	_free_pipeline_bundle(bundle)


# ============================================================
# ТЕСТОВЫЕ ЗАВИСИМОСТИ
# ============================================================

func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	return battle_state


func _make_pipeline_bundle(battle_state : BattleState) -> Dictionary:
	var registry := AbilityAlgorithmRegistry.new()
	var availability := AbilityAvailabilityService.new(registry)
	var targeting := TargetingService.new()
	var builder := AbilityImpactPlanBuilder.new()
	var status_effect_system := StatusEffectSystem.new()
	var event_log := CombatEventLog.new()
	var reaction_queue := ReactionQueue.new()
	var reaction_system := ReactionSystem.new()
	reaction_system.configure(reaction_queue, builder, targeting)
	var death_resolver := DeathResolver.new()
	var impact_executor := ImpactExecutor.new()
	impact_executor.configure(
		InteractionResolver.new(),
		status_effect_system,
		event_log,
		reaction_queue,
		reaction_system,
		ImpactConditionEvaluator.new(),
		builder,
		death_resolver
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

	return {
		"battle_state": battle_state,
		"ability_pipeline": ability_pipeline,
		"turn_pipeline": turn_pipeline,
		"event_queue": event_queue,
		"impact_executor": impact_executor,
		"status_effect_system": status_effect_system,
		"combat_event_log": event_log,
		"targeting_service": targeting,
		"algorithm_registry": registry
	}


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
	data.initiative = initiative
	data.armor = 0
	data.movement = 2
	return data


func _make_effect_impact(
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	effect : EffectData,
	source_ability : UnitAbilityData
) -> Impact:
	var impact := Impact.create(
		StringName("%s_effect" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.APPLY_EFFECT,
		Impact.InteractionType.EFFECT,
		&"",
		0,
		0
	)
	impact.source_ability_data = source_ability
	impact.effect_data = effect
	return impact


func _execute_damage_plan(
	executor : ImpactExecutor,
	battle_state : BattleState,
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	magnitude : int
) -> ImpactPlanExecutionResult:
	var impact := Impact.create(
		StringName("%s_damage" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.DAMAGE,
		Impact.InteractionType.MELEE,
		&"physical",
		magnitude,
		0
	)
	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	return executor.execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)


func _get_rule(
	effect : EffectData,
	rule_type : PassiveRuleData.RuleType
) -> PassiveRuleData:
	for rule in effect.passive_rules:
		if rule != null and rule.rule_type == rule_type:
			return rule

	return null


func _has_event_kind(
	event_log : CombatEventLog,
	event_kind : CombatEvent.Kind
) -> bool:
	for event in event_log.history:
		if event != null and event.kind == event_kind:
			return true

	return false


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	for key in ["ability_pipeline", "turn_pipeline", "event_queue"]:
		var node := bundle.get(key, null) as Node

		if node != null:
			node.free()
