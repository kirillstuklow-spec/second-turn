extends SceneTree


const TEST_SEED : int = 20260805

const FIRE_ARROW_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/FireArrow.tres"
)
const BURNING_PATH : String = "res://Resources/Effects/Burning.tres"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_schema_and_first_hit()
	_test_existing_burning_uses_captured_source_then_refreshes()
	_test_effect_defense_blocks_application()
	_test_late_effect_defense_blocks_trigger_but_keeps_status()
	_test_each_health_loss_and_self_damage_trigger_separately()
	_test_duration_and_regeneration_rule()

	print(
		"FireArrowEffectsSmokeTest: PASS — declarative Fire Arrow, "
		+ "EFFECT defenses without armor, per-HEALTH_LOST Burning, "
		+ "source refresh, two carrier activations and regeneration block"
	)

	quit()


func _test_resource_schema_and_first_hit() -> void:
	var fire_arrow := _load_fire_arrow()
	var burning_data := load(BURNING_PATH) as EffectData
	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(fire_arrow)

	assert(schema.is_valid, schema.get_summary())
	assert(burning_data != null)
	assert(burning_data.triggers.size() == 1)
	assert(
		burning_data.triggers[0].event_kind
		== CombatEvent.Kind.HEALTH_LOST
	)
	assert(fire_arrow.impact_plan_data != null)
	assert(fire_arrow.impact_plan_data.nodes.size() == 3)
	assert(
		fire_arrow.impact_plan_data.nodes[1].transition_condition.condition_type
		== ImpactConditionData.ConditionType.PARENT_MAGNITUDE_APPLIED_AT_LEAST
	)
	assert(
		fire_arrow.impact_plan_data.nodes[2].transition_condition.condition_type
		== ImpactConditionData.ConditionType.PARENT_EFFECT_APPLIED_OR_REFRESHED
	)

	var bundle := _make_pipeline_battle(fire_arrow, false)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var combat_event_log := bundle["combat_event_log"] as CombatEventLog
	var attacker := bundle["attacker_a"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime
	var hp_before := target.current_hp
	var execution := pipeline.execute_ability(
		attacker,
		target,
		attacker.active_abilities[0],
		target.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(execution.impact_plan.topology == ImpactPlan.Topology.TREE)
	assert(execution.get_impact_results().size() == 3)
	assert(execution.get_impact_results()[0].magnitude_applied == 3)
	var burning_application : EffectApplicationResult = (
		execution.get_impact_results()[1].effect_application_result
	)
	var regeneration_application : EffectApplicationResult = (
		execution.get_impact_results()[2].effect_application_result
	)
	assert(
		burning_application.status
		== EffectApplicationResult.Status.APPLIED
	)
	assert(
		regeneration_application.status
		== EffectApplicationResult.Status.APPLIED
	)
	assert(execution.impact_execution_result.reaction_execution_results.is_empty())
	assert(target.current_hp == hp_before - 3)
	assert(target.active_effects.size() == 2)
	assert(combat_event_log.history.size() == 4)
	assert(combat_event_log.history[0].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(combat_event_log.history[1].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(
		combat_event_log.history[1].health_loss_cause
		== CombatEvent.HealthLossCause.DAMAGE
	)
	assert(combat_event_log.history[2].kind == CombatEvent.Kind.EFFECT_APPLIED)
	assert(combat_event_log.history[3].kind == CombatEvent.Kind.EFFECT_APPLIED)

	var burning := target.get_active_effect(&"status.burning")
	var regeneration_block := target.get_active_effect(
		&"status.regeneration_blocked"
	)

	assert(burning != null)
	assert(regeneration_block != null)
	assert(burning.source_unit == attacker)
	assert(burning.remaining_duration == 2)
	assert(regeneration_block.remaining_duration == 2)

	_free_pipeline_bundle(bundle)


func _test_existing_burning_uses_captured_source_then_refreshes() -> void:
	var fire_arrow := _load_fire_arrow()
	var bundle := _make_pipeline_battle(fire_arrow, true)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var attacker_a := bundle["attacker_a"] as UnitRuntime
	var attacker_b := bundle["attacker_b"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime
	var battle_state := bundle["battle_state"] as BattleState

	var first := pipeline.execute_ability(
		attacker_a,
		target,
		attacker_a.active_abilities[0],
		target.cell
	)
	assert(first.was_committed())

	var burning_before := target.get_active_effect(&"status.burning")
	var runtime_id_before := burning_before.runtime_id
	var hp_before_second := target.current_hp

	battle_state.set_active_unit(attacker_b)
	attacker_b.start_round(1)
	attacker_b.start_activation(1, 1)

	var second := pipeline.execute_ability(
		attacker_b,
		target,
		attacker_b.active_abilities[0],
		target.cell
	)

	assert(second.was_committed())
	assert(target.current_hp == hp_before_second - 4)
	assert(second.impact_execution_result.reaction_execution_results.size() == 1)

	var reaction_result : ImpactPlanExecutionResult = (
		second.impact_execution_result.reaction_execution_results[0]
	)
	assert(reaction_result.is_successful())
	assert(reaction_result.impact_results.size() == 1)
	assert(reaction_result.impact_results[0].magnitude_applied == 1)
	assert(
		reaction_result.impact_results[0].impact.interaction_type
		== Impact.InteractionType.EFFECT
	)
	assert(reaction_result.impact_results[0].impact.source_unit == attacker_a)
	assert(
		reaction_result.impact_results[0].impact.origin_effect_runtime_id
		== runtime_id_before
	)

	var burning_after := target.get_active_effect(&"status.burning")
	assert(burning_after.runtime_id == runtime_id_before)
	assert(burning_after.source_unit == attacker_b)
	assert(burning_after.remaining_duration == 2)
	assert(
		second.get_impact_results()[1].effect_application_result.status
		== EffectApplicationResult.Status.REFRESHED
	)
	assert(
		second.get_impact_results()[2].effect_application_result.status
		== EffectApplicationResult.Status.REFRESHED
	)

	_free_pipeline_bundle(bundle)


func _test_effect_defense_blocks_application() -> void:
	var fire_arrow := _load_fire_arrow()
	var bundle := _make_pipeline_battle(fire_arrow, false)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var attacker := bundle["attacker_a"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime
	target.active_defenses.append("effect")
	var hp_before := target.current_hp

	var execution := pipeline.execute_ability(
		attacker,
		target,
		attacker.active_abilities[0],
		target.cell
	)

	assert(execution.was_committed())
	assert(target.current_hp == hp_before - 3)
	assert(target.get_active_effect(&"status.burning") == null)
	assert(target.get_active_effect(&"status.regeneration_blocked") == null)
	assert(not target.active_defenses.has("effect"))
	assert(
		execution.get_impact_results()[1].outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		execution.get_impact_results()[2].outcome
		== ImpactResult.Outcome.SKIPPED_CONDITION
	)

	_free_pipeline_bundle(bundle)


func _test_late_effect_defense_blocks_trigger_but_keeps_status() -> void:
	var fire_arrow := _load_fire_arrow()
	var bundle := _make_pipeline_battle(fire_arrow, false)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var executor := bundle["executor"] as ImpactExecutor
	var battle_state := bundle["battle_state"] as BattleState
	var attacker := bundle["attacker_a"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	var first := pipeline.execute_ability(
		attacker,
		target,
		attacker.active_abilities[0],
		target.cell
	)
	assert(first.was_committed())
	var burning := target.get_active_effect(&"status.burning")
	assert(burning != null)

	target.active_defenses.append("effect")
	var hp_before_blocked_trigger := target.current_hp
	var trigger_execution := _execute_damage_plan(
		executor,
		battle_state,
		&"late_defense_trigger",
		attacker,
		target,
		1,
		Impact.InteractionType.RANGED,
		&"physical",
		0
	)

	assert(trigger_execution.is_successful())
	assert(target.current_hp == hp_before_blocked_trigger - 1)
	assert(trigger_execution.reaction_execution_results.size() == 1)
	var blocked_burning_result : ImpactResult = (
		trigger_execution.reaction_execution_results[0].impact_results[0]
	)
	assert(
		blocked_burning_result.outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		blocked_burning_result.consumed_defense == &"effect"
	)
	assert(not target.active_defenses.has("effect"))
	assert(target.get_active_effect(&"status.burning") == burning)

	# Броня 5 гарантированно остановила бы урон, если бы EFFECT её проверял.
	# Корневой удар проходит с бронебойностью 5, а горение — без броска брони.
	target.armor = 5
	var hp_before_armor_check := target.current_hp
	var armor_execution := _execute_damage_plan(
		executor,
		battle_state,
		&"effect_ignores_armor",
		attacker,
		target,
		1,
		Impact.InteractionType.RANGED,
		&"physical",
		5
	)
	var burning_result : ImpactResult = (
		armor_execution.reaction_execution_results[0].impact_results[0]
	)

	assert(target.current_hp == hp_before_armor_check - 2)
	assert(burning_result.magnitude_applied == 1)
	assert(not burning_result.interaction_resolution.armor_was_checked)

	_free_pipeline_bundle(bundle)


func _test_each_health_loss_and_self_damage_trigger_separately() -> void:
	var fire_arrow := _load_fire_arrow()
	var bundle := _make_pipeline_battle(fire_arrow, false)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var executor := bundle["executor"] as ImpactExecutor
	var battle_state := bundle["battle_state"] as BattleState
	var attacker := bundle["attacker_a"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	assert(pipeline.execute_ability(
		attacker,
		target,
		attacker.active_abilities[0],
		target.cell
	).was_committed())

	var hp_before_multi := target.current_hp
	var multi_plan := ImpactPlan.create(
		&"two_damage_impacts",
		ImpactPlan.Topology.TREE
	)

	for impact_index in range(2):
		var impact := Impact.create(
			StringName("multi_damage_%d" % impact_index),
			multi_plan.execution_id,
			attacker,
			target,
			target.cell,
			Impact.Operation.DAMAGE,
			Impact.InteractionType.RANGED,
			&"physical",
			1,
			0
		)
		impact.order_index = impact_index
		assert(multi_plan.add_root_impact(impact))

	var multi_execution := executor.execute(
		multi_plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)

	assert(multi_execution.is_successful())
	assert(multi_execution.reaction_execution_results.size() == 2)
	assert(target.current_hp == hp_before_multi - 4)

	var hp_before_self_damage := target.current_hp
	var self_execution := _execute_damage_plan(
		executor,
		battle_state,
		&"self_damage",
		target,
		target,
		1,
		Impact.InteractionType.MELEE,
		&"physical",
		0
	)

	assert(self_execution.is_successful())
	assert(self_execution.reaction_execution_results.size() == 1)
	assert(target.current_hp == hp_before_self_damage - 2)
	var self_burning_result : ImpactResult = (
		self_execution.reaction_execution_results[0].impact_results[0]
	)
	assert(
		self_burning_result.impact.source_unit == attacker
	)

	_free_pipeline_bundle(bundle)


func _test_duration_and_regeneration_rule() -> void:
	var burning_data := load(BURNING_PATH) as EffectData
	var fire_arrow := _load_fire_arrow()
	var bundle := _make_pipeline_battle(fire_arrow, true)
	var executor := bundle["executor"] as ImpactExecutor
	var status_effect_system := bundle["status_effect_system"] as StatusEffectSystem
	var battle_state := bundle["battle_state"] as BattleState
	var attacker_a := bundle["attacker_a"] as UnitRuntime
	var attacker_b := bundle["attacker_b"] as UnitRuntime
	var target := bundle["target"] as UnitRuntime

	assert(burning_data != null)
	battle_state.set_active_unit(target)
	battle_state.turn_state.activation_serial = 10

	var apply_effect := Impact.create(
		&"duration_apply_burning",
		&"duration_effect_execution",
		attacker_a,
		target,
		target.cell,
		Impact.Operation.APPLY_EFFECT,
		Impact.InteractionType.EFFECT,
		&"fire",
		0,
		0
	)
	apply_effect.effect_data = burning_data
	var apply_plan := ImpactPlan.create(
		apply_effect.execution_id,
		ImpactPlan.Topology.TREE
	)
	assert(apply_plan.add_root_impact(apply_effect))
	var apply_execution := executor.execute(
		apply_plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)
	assert(apply_execution.is_successful())

	var burning := target.get_active_effect(&"status.burning")
	assert(burning != null)
	assert(burning.remaining_duration == 2)

	# Обновление в той же активации перезаписывает источник и вновь ставит 2.
	apply_effect = Impact.create(
		&"duration_refresh_burning",
		&"duration_refresh_execution",
		attacker_b,
		target,
		target.cell,
		Impact.Operation.APPLY_EFFECT,
		Impact.InteractionType.EFFECT,
		&"fire",
		0,
		0
	)
	apply_effect.effect_data = burning_data
	apply_plan = ImpactPlan.create(
		apply_effect.execution_id,
		ImpactPlan.Topology.TREE
	)
	assert(apply_plan.add_root_impact(apply_effect))
	assert(executor.execute(
		apply_plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	).is_successful())
	assert(burning.source_unit == attacker_b)
	assert(burning.remaining_duration == 2)

	status_effect_system.finish_activation(target, 10)
	assert(burning.remaining_duration == 2)
	status_effect_system.finish_activation(target, 11)
	assert(burning.remaining_duration == 1)
	status_effect_system.finish_activation(target, 12)
	assert(target.get_active_effect(&"status.burning") == null)

	# Полная Огненная стрела добавляет пассивный запрет только регенерации.
	battle_state.set_active_unit(attacker_a)
	attacker_a.action_points_remaining = 1
	var pipeline := bundle["pipeline"] as AbilityPipeline
	assert(pipeline.execute_ability(
		attacker_a,
		target,
		attacker_a.active_abilities[0],
		target.cell
	).was_committed())

	var direct_heal := _execute_heal_plan(
		executor,
		battle_state,
		&"direct_heal",
		target,
		target,
		1,
		Impact.HealingKind.DIRECT
	)
	assert(direct_heal.impact_results[0].magnitude_applied == 1)
	var hp_before_regeneration := target.current_hp
	var regeneration := _execute_heal_plan(
		executor,
		battle_state,
		&"regeneration_heal",
		target,
		target,
		2,
		Impact.HealingKind.REGENERATION
	)
	assert(
		regeneration.impact_results[0].outcome
		== ImpactResult.Outcome.BLOCKED_PASSIVE_RULE
	)
	assert(target.current_hp == hp_before_regeneration)

	_free_pipeline_bundle(bundle)


func _make_pipeline_battle(
	fire_arrow : UnitAbilityData,
	include_second_attacker : bool
) -> Dictionary:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()

	var attacker_a_data := _make_unit_data("pyromaniac_a", "Pyromaniac A")
	attacker_a_data.active_abilities.append(fire_arrow)
	var attacker_a := battle_state.spawn_unit(attacker_a_data, 1, 0, 2)
	var attacker_b : UnitRuntime = null

	if include_second_attacker:
		var attacker_b_data := _make_unit_data(
			"pyromaniac_b",
			"Pyromaniac B"
		)
		attacker_b_data.active_abilities.append(fire_arrow)
		attacker_b = battle_state.spawn_unit(attacker_b_data, 1, 1, 2)

	var target := battle_state.spawn_unit(
		_make_unit_data("fire_target", "Fire Target"),
		2,
		6,
		2
	)
	assert(attacker_a != null)
	assert(target != null)

	battle_state.set_active_unit(attacker_a)
	attacker_a.start_round(1)
	attacker_a.start_activation(1, 0)

	var registry := AbilityAlgorithmRegistry.new()
	var availability := AbilityAvailabilityService.new(registry)
	var targeting := TargetingService.new()
	var builder := AbilityImpactPlanBuilder.new()
	var status_effect_system := StatusEffectSystem.new()
	var combat_event_log := CombatEventLog.new()
	var reaction_queue := ReactionQueue.new()
	var reaction_system := ReactionSystem.new()
	reaction_system.configure(reaction_queue, builder)
	var executor := ImpactExecutor.new()
	executor.configure(
		InteractionResolver.new(),
		status_effect_system,
		combat_event_log,
		reaction_queue,
		reaction_system,
		ImpactConditionEvaluator.new(),
		builder
	)
	var pipeline := AbilityPipeline.new()
	root.add_child(pipeline)
	pipeline.configure(
		battle_state,
		availability,
		registry,
		targeting,
		builder,
		executor
	)

	return {
		"battle_state": battle_state,
		"attacker_a": attacker_a,
		"attacker_b": attacker_b,
		"target": target,
		"pipeline": pipeline,
		"executor": executor,
		"status_effect_system": status_effect_system,
		"combat_event_log": combat_event_log
	}


func _execute_damage_plan(
	executor : ImpactExecutor,
	battle_state : BattleState,
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	magnitude : int,
	interaction_type : Impact.InteractionType,
	source_type : StringName,
	armor_penetration : int
) -> ImpactPlanExecutionResult:
	var impact := Impact.create(
		StringName("%s_damage" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.DAMAGE,
		interaction_type,
		source_type,
		magnitude,
		armor_penetration
	)
	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	return executor.execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)


func _execute_heal_plan(
	executor : ImpactExecutor,
	battle_state : BattleState,
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	magnitude : int,
	healing_kind : Impact.HealingKind
) -> ImpactPlanExecutionResult:
	var impact := Impact.create(
		StringName("%s_heal" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.HEAL,
		Impact.InteractionType.HEALING,
		&"holy",
		magnitude,
		0
	)
	impact.healing_kind = healing_kind
	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	return executor.execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)


func _make_unit_data(unit_id : String, unit_name : String) -> UnitData:
	var data := UnitData.new()
	data.unit_id = unit_id
	data.unit_name = unit_name
	data.max_hp = 50
	data.armor = 0
	data.movement = 3
	data.initiative = 10
	return data


func _load_fire_arrow() -> UnitAbilityData:
	var fire_arrow := load(FIRE_ARROW_PATH) as UnitAbilityData
	assert(fire_arrow != null)
	return fire_arrow


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState
	var pipeline := bundle.get("pipeline", null) as AbilityPipeline

	if battle_state != null:
		battle_state.clear()

	if pipeline != null:
		pipeline.free()
