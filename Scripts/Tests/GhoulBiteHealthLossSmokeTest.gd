extends SceneTree


const TEST_SEED : int = 20260811

const GHOUL_PATH : String = "res://Resources/Unit/GhoulData.tres"
const BITE_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/GhoulBite.tres"
)
const KILL_HEAL_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/GhoulBiteKillHeal.tres"
)
const DECAY_PATH : String = "res://Resources/Effects/Decay.tres"
const WHIP_DRIVEN_PATH : String = (
	"res://Resources/Effects/WhipDriven.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract()
	_test_surviving_target_receives_decay_without_kill_heal()
	_test_confirmed_direct_kill_heals_ghoul()
	_test_prevented_death_does_not_heal_ghoul()
	_test_reaction_depth_decay_kill_does_not_count_as_direct_bite()

	print(
		"GhoulBiteHealthLossSmokeTest: PASS — Bite damage and Decay, "
		+ "HEALTH_LOST event, exact source-ability trigger, confirmed "
		+ "direct-kill healing, no heal after DEATH_PREVENTED or a delayed "
		+ "EFFECT kill"
	)
	quit()


# ============================================================
# РЕСУРСНЫЙ КОНТРАКТ
# ============================================================

func _test_resource_contract() -> void:
	var ghoul_data := load(GHOUL_PATH) as UnitData
	var bite := load(BITE_PATH) as UnitAbilityData
	var kill_heal := load(KILL_HEAL_PATH) as UnitAbilityData
	var decay := load(DECAY_PATH) as EffectData
	assert(ghoul_data != null)
	assert(bite != null)
	assert(kill_heal != null)
	assert(decay != null)
	assert(ghoul_data.active_abilities.size() == 2)
	assert(ghoul_data.active_abilities[0] == bite)
	assert(ghoul_data.passive_abilities.size() == 1)
	assert(ghoul_data.passive_abilities[0] == kill_heal)

	assert(bite.action_point_cost == 1)
	assert(bite.ability.activation_mode == AbilityData.ActivationMode.ACTIVE)
	assert(bite.ability.action_type == AbilityData.ActionType.ATTACK)
	assert(bite.ability.target_rule_id == "single_adjacent_enemy")
	assert(bite.impact_plan_data.nodes.size() == 2)

	var damage_node : ImpactNodeData = bite.impact_plan_data.nodes[0]
	var decay_node : ImpactNodeData = bite.impact_plan_data.nodes[1]
	assert(damage_node.operation == Impact.Operation.DAMAGE)
	assert(damage_node.interaction_type == Impact.InteractionType.MELEE)
	assert(damage_node.source_type == "decay")
	assert(damage_node.magnitude == 2)
	assert(decay_node.parent_node_id == damage_node.node_id)
	assert(decay_node.operation == Impact.Operation.APPLY_EFFECT)
	assert(decay_node.effect_data == decay)

	assert(
		kill_heal.ability.activation_mode
		== AbilityData.ActivationMode.TRIGGERED
	)
	assert(kill_heal.ability.action_type == AbilityData.ActionType.HEAL)
	assert(kill_heal.action_point_cost == 0)
	assert(kill_heal.triggers.size() == 1)
	var trigger : AbilityTriggerData = kill_heal.triggers[0]
	assert(trigger.event_kind == CombatEvent.Kind.DEATH_CONFIRMED)
	assert(
		trigger.owner_relation
		== AbilityTriggerData.OwnerRelation.OWNER_IS_EVENT_SOURCE
	)
	assert(
		trigger.event_source_relation
		== AbilityTriggerData.EventSourceRelation.SELF
	)
	assert(
		trigger.interaction_filter
		== AbilityTriggerData.InteractionFilter.MELEE
	)
	assert(trigger.source_ability_filter == bite)
	assert(not trigger.accept_reaction_events)
	assert(kill_heal.impact_plan_data.nodes.size() == 1)
	var heal_node : ImpactNodeData = kill_heal.impact_plan_data.nodes[0]
	assert(heal_node.operation == Impact.Operation.HEAL)
	assert(heal_node.interaction_type == Impact.InteractionType.HEALING)
	assert(heal_node.target_reference == ImpactNodeData.TargetReference.ABILITY_SOURCE)
	assert(heal_node.magnitude == 2)

	var registry := AbilityAlgorithmRegistry.new()
	var bite_schema := registry.validate_unit_ability(bite)
	var heal_schema := registry.validate_unit_ability(kill_heal)
	assert(bite_schema.is_valid, bite_schema.get_summary())
	assert(heal_schema.is_valid, heal_schema.get_summary())


# ============================================================
# ОБЫЧНЫЙ УДАР И НАЛОЖЕНИЕ РАЗЛОЖЕНИЯ
# ============================================================

func _test_surviving_target_receives_decay_without_kill_heal() -> void:
	var battle_state := _make_battle_state()
	var ghoul := _spawn_ghoul(battle_state, 1, 2, 2)
	var target := battle_state.spawn_unit(
		_make_unit_data("bite_survivor", "Bite Survivor", 10),
		2,
		3,
		2
	)
	assert(ghoul != null)
	assert(target != null)
	_prepare_ghoul_activation(battle_state, ghoul)
	ghoul.current_hp = 5

	var bundle := _make_pipeline_bundle(battle_state)
	var bite_runtime := ghoul.get_active_ability_runtime(
		load(BITE_PATH) as UnitAbilityData
	)
	assert(bite_runtime != null)
	var ghoul_hp_before := ghoul.current_hp
	var target_hp_before := target.current_hp
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		ghoul,
		target,
		bite_runtime,
		target.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(target.current_hp == target_hp_before - 2)
	assert(target.get_active_effect(&"status.decay") != null)
	assert(ghoul.current_hp == ghoul_hp_before)
	assert(execution.impact_execution_result.reaction_execution_results.is_empty())

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 3)
	assert(event_log.history[0].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[1].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(
		event_log.history[1].health_loss_cause
		== CombatEvent.HealthLossCause.DAMAGE
	)
	assert(event_log.history[1].source_ability_data == load(BITE_PATH))
	assert(event_log.history[2].kind == CombatEvent.Kind.EFFECT_APPLIED)

	_free_pipeline_bundle(bundle)


# ============================================================
# ПОДТВЕРЖДЁННОЕ УБИЙСТВО И ЛЕЧЕНИЕ
# ============================================================

func _test_confirmed_direct_kill_heals_ghoul() -> void:
	var battle_state := _make_battle_state()
	var ghoul := _spawn_ghoul(battle_state, 1, 2, 2)
	var target := battle_state.spawn_unit(
		_make_unit_data("bite_victim", "Bite Victim", 2),
		2,
		3,
		2
	)
	assert(ghoul != null)
	assert(target != null)
	_prepare_ghoul_activation(battle_state, ghoul)
	ghoul.current_hp = 5

	var bundle := _make_pipeline_bundle(battle_state)
	var bite_runtime := ghoul.get_active_ability_runtime(
		load(BITE_PATH) as UnitAbilityData
	)
	assert(bite_runtime != null)
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		ghoul,
		target,
		bite_runtime,
		target.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(target.is_dead())
	assert(target.cell == null)
	assert(target.get_active_effect(&"status.decay") == null)
	assert(ghoul.current_hp == 7)
	assert(
		execution.impact_execution_result.reaction_execution_results.size()
		== 1
	)
	var heal_result : ImpactResult = (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)
	assert(heal_result.magnitude_applied == 2)
	assert(heal_result.impact.source_unit == ghoul)
	assert(heal_result.impact.target_unit == ghoul)
	assert(
		heal_result.impact.source_ability_data
		== (load(KILL_HEAL_PATH) as UnitAbilityData)
	)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 4)
	var damage_event : CombatEvent = event_log.history[0]
	var loss_event : CombatEvent = event_log.history[1]
	var death_event : CombatEvent = event_log.history[2]
	var heal_event : CombatEvent = event_log.history[3]
	assert(damage_event.kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(loss_event.kind == CombatEvent.Kind.HEALTH_LOST)
	assert(death_event.kind == CombatEvent.Kind.DEATH_CONFIRMED)
	assert(death_event.cause_event_id == damage_event.event_id)
	assert(death_event.source_ability_data == load(BITE_PATH))
	assert(heal_event.kind == CombatEvent.Kind.HEALING_APPLIED)
	assert(heal_event.target_unit == ghoul)
	assert(heal_event.hp_delta == 2)

	_free_pipeline_bundle(bundle)


func _test_prevented_death_does_not_heal_ghoul() -> void:
	var battle_state := _make_battle_state()
	var ghoul := _spawn_ghoul(battle_state, 1, 2, 2)
	var target := battle_state.spawn_unit(
		_make_unit_data("bite_saved_target", "Bite Saved Target", 2),
		2,
		3,
		2
	)
	assert(ghoul != null)
	assert(target != null)
	_prepare_ghoul_activation(battle_state, ghoul)
	ghoul.current_hp = 5

	var last_stand := EffectRuntime.new()
	last_stand.setup(
		&"test_bite_last_stand",
		load(WHIP_DRIVEN_PATH) as EffectData,
		target,
		null,
		target,
		battle_state.turn_state.activation_serial,
		battle_state.round_number
	)
	target.active_effects.append(last_stand)

	var bundle := _make_pipeline_bundle(battle_state)
	var bite_runtime := ghoul.get_active_ability_runtime(
		load(BITE_PATH) as UnitAbilityData
	)
	assert(bite_runtime != null)
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		ghoul,
		target,
		bite_runtime,
		target.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(target.is_alive)
	assert(target.current_hp == 1)
	assert(target.get_active_effect(&"status.whip_driven") == null)
	assert(ghoul.current_hp == 5)
	assert(execution.impact_execution_result.reaction_execution_results.is_empty())

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(_has_event_kind(event_log, CombatEvent.Kind.DEATH_PREVENTED))
	assert(not _has_event_kind(event_log, CombatEvent.Kind.DEATH_CONFIRMED))

	_free_pipeline_bundle(bundle)


func _test_reaction_depth_decay_kill_does_not_count_as_direct_bite() -> void:
	var battle_state := _make_battle_state()
	var ghoul := _spawn_ghoul(battle_state, 1, 2, 2)
	var target := battle_state.spawn_unit(
		_make_unit_data("bite_decay_victim", "Bite Decay Victim", 1),
		2,
		3,
		2
	)
	assert(ghoul != null)
	assert(target != null)
	ghoul.current_hp = 5

	var bundle := _make_pipeline_bundle(battle_state)
	var executor := bundle["impact_executor"] as ImpactExecutor
	var impact := Impact.create(
		&"test_bite_decay_kill_damage",
		&"test_bite_decay_kill",
		ghoul,
		target,
		target.cell,
		Impact.Operation.DAMAGE,
		Impact.InteractionType.EFFECT,
		&"decay",
		1,
		0
	)
	impact.source_ability_data = load(BITE_PATH) as UnitAbilityData
	impact.reaction_depth = 1
	var plan := ImpactPlan.create(
		&"test_bite_decay_kill",
		ImpactPlan.Topology.TREE
	)
	assert(plan.add_root_impact(impact))
	var execution := executor.execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)

	assert(execution.is_successful())
	assert(target.is_dead())
	assert(ghoul.current_hp == 5)
	assert(execution.reaction_execution_results.is_empty())
	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(_has_event_kind(event_log, CombatEvent.Kind.DEATH_CONFIRMED))
	assert(not _has_event_kind(event_log, CombatEvent.Kind.HEALING_APPLIED))

	_free_pipeline_bundle(bundle)


# ============================================================
# ТЕСТОВЫЕ ЗАВИСИМОСТИ
# ============================================================

func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	return battle_state


func _spawn_ghoul(
	battle_state : BattleState,
	team_id : int,
	x : int,
	y : int
) -> UnitRuntime:
	return battle_state.spawn_unit(
		load(GHOUL_PATH) as UnitData,
		team_id,
		x,
		y
	)


func _prepare_ghoul_activation(
	battle_state : BattleState,
	ghoul : UnitRuntime
) -> void:
	battle_state.set_active_unit(ghoul)
	ghoul.start_round(1)
	ghoul.start_activation(1, 0)


func _make_unit_data(
	unit_id : String,
	unit_name : String,
	max_hp : int
) -> UnitData:
	var data := UnitData.new()
	data.unit_id = unit_id
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.initiative = 10
	data.armor = 0
	data.movement = 2
	return data


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
	root.add_child(ability_pipeline)
	ability_pipeline.configure(
		battle_state,
		availability,
		registry,
		targeting,
		builder,
		impact_executor
	)

	return {
		"battle_state": battle_state,
		"ability_pipeline": ability_pipeline,
		"impact_executor": impact_executor,
		"combat_event_log": event_log
	}


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

	var ability_pipeline := bundle.get("ability_pipeline", null) as Node

	if ability_pipeline != null:
		ability_pipeline.free()
