extends SceneTree


const TEST_SEED : int = 20260808

const PENITENT_PATH : String = (
	"res://Resources/Unit/PenitentData.tres"
)
const HOOK_STRIKE_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/HookStrike.tres"
)
const LAST_STEP_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/LastStep.tres"
)
const MELEE_STRIKE_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/MeleeStrike.tres"
)
const POISONING_DART_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/PoisoningDart.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_penitent_resource_contract()
	_test_unit_death_state_machine()
	_test_death_confirmation_choice_and_shared_attack()
	_test_last_step_uses_normal_defense_rules()
	_test_last_step_skips_without_adjacent_target()
	_test_activation_end_pauses_and_resumes_after_choice()

	print(
		"PenitentLastStepSmokeTest: PASS — Penitent UnitData, shared Hook "
		+ "Strike plan, ALIVE > DEATH_PENDING > DEAD, confirmed-death "
		+ "event, freed origin cell, mandatory PendingDecision, normal "
		+ "command gate, MELEE + PHYSICAL resolution, no-target skip, "
		+ "activation-end "
		+ "pause/resume and victory only after post-mortem reactions"
	)

	quit()


# ============================================================
# РЕСУРСНЫЙ КОНТРАКТ
# ============================================================

func _test_penitent_resource_contract() -> void:
	var penitent_data := load(PENITENT_PATH) as UnitData
	var hook_strike := load(HOOK_STRIKE_PATH) as UnitAbilityData
	var last_step := load(LAST_STEP_PATH) as UnitAbilityData
	assert(penitent_data != null)
	assert(hook_strike != null)
	assert(last_step != null)
	assert(penitent_data.unit_id == "penitent")
	assert(penitent_data.unit_name == "Кающийся")
	assert(penitent_data.initiative == 45)
	assert(penitent_data.max_hp == 4)
	assert(penitent_data.armor == 0)
	assert(penitent_data.movement == 2)
	assert(penitent_data.defenses.is_empty())
	assert(penitent_data.immunities.is_empty())
	assert(penitent_data.active_abilities[0] == hook_strike)
	assert(penitent_data.passive_abilities[0] == last_step)
	assert(hook_strike.impact_plan_data == last_step.impact_plan_data)

	var registry := AbilityAlgorithmRegistry.new()
	var hook_schema := registry.validate_unit_ability(hook_strike)
	var last_step_schema := registry.validate_unit_ability(last_step)
	assert(hook_schema.is_valid, hook_schema.get_summary())
	assert(last_step_schema.is_valid, last_step_schema.get_summary())
	assert(hook_strike.action_point_cost == 1)
	assert(last_step.action_point_cost == 0)
	assert(last_step.triggers.size() == 1)

	var trigger := last_step.triggers[0]
	assert(trigger.event_kind == CombatEvent.Kind.DEATH_CONFIRMED)
	assert(
		trigger.target_selection_policy
		== AbilityTriggerData.TargetSelectionPolicy.PLAYER_CHOICE
	)
	assert(not trigger.require_owner_alive)
	assert(not trigger.require_event_source_alive)

	var damage_node := hook_strike.impact_plan_data.nodes[0]
	assert(damage_node.target_reference == ImpactNodeData.TargetReference.SELECTED_TARGET)
	assert(damage_node.interaction_type == Impact.InteractionType.MELEE)
	assert(damage_node.source_type == "physical")
	assert(damage_node.magnitude == 2)
	assert(damage_node.armor_penetration == 0)


# ============================================================
# СОСТОЯНИЯ СМЕРТИ RUNTIME
# ============================================================

func _test_unit_death_state_machine() -> void:
	var unit := UnitRuntime.new()
	unit.setup(_make_unit_data("death_states", "Death States", 4, 1), 1)
	assert(unit.death_state == UnitRuntime.DeathState.ALIVE)
	assert(unit.is_alive)

	unit.take_damage(4)
	assert(unit.death_state == UnitRuntime.DeathState.DEATH_PENDING)
	assert(not unit.is_alive)
	assert(unit.current_hp == 0)
	assert(unit.cancel_pending_death(2))
	assert(unit.death_state == UnitRuntime.DeathState.ALIVE)
	assert(unit.is_alive)
	assert(unit.current_hp == 2)

	unit.take_damage(2)
	assert(unit.is_death_pending())
	assert(unit.confirm_death())
	assert(unit.is_dead())
	assert(not unit.confirm_death())


# ============================================================
# ПОДТВЕРЖДЕНИЕ СМЕРТИ И РУЧНОЙ ВЫБОР
# ============================================================

func _test_death_confirmation_choice_and_shared_attack() -> void:
	var battle_state := _make_battle_state()
	var melee_strike := load(MELEE_STRIKE_PATH) as UnitAbilityData
	var attacker_data := _make_unit_data("killer", "Killer", 10, 20)
	attacker_data.active_abilities.append(melee_strike)
	var other_enemy_data := _make_unit_data(
		"other_enemy",
		"Other Enemy",
		10,
		10
	)
	var attacker := battle_state.spawn_unit(attacker_data, 1, 0, 2)
	var penitent := battle_state.spawn_unit(
		load(PENITENT_PATH) as UnitData,
		2,
		1,
		2
	)
	var other_enemy := battle_state.spawn_unit(
		other_enemy_data,
		1,
		2,
		2
	)
	assert(attacker != null)
	assert(penitent != null)
	assert(other_enemy != null)
	battle_state.set_active_unit(attacker)
	attacker.start_round(1)
	attacker.start_activation(1, 0)
	penitent.start_round(1)
	other_enemy.start_round(1)

	var bundle := _make_pipeline_bundle(battle_state)
	var pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var execution := pipeline.execute_ability(
		attacker,
		penitent,
		attacker.active_abilities[0],
		penitent.cell
	)
	assert(execution.was_committed(), execution.message)
	assert(penitent.death_state == UnitRuntime.DeathState.DEAD)
	assert(not penitent.is_alive)
	assert(penitent.cell == null)
	assert(penitent.death_origin_x == 1)
	assert(penitent.death_origin_y == 2)
	assert(battle_state.get_cell_at(1, 2).occupying_unit == null)
	assert(not battle_state.is_battle_over)
	assert(battle_state.pending_decision != null)
	assert(execution.impact_execution_result.is_waiting_for_decision())
	assert(battle_state.pending_decision.options.has(attacker))
	assert(battle_state.pending_decision.options.has(other_enemy))
	assert(not battle_state.check_victory_condition())

	var decision_id := battle_state.pending_decision.decision_id
	var dispatcher := bundle["command_dispatcher"] as CommandDispatcher
	assert(dispatcher.dispatch_command({"type": "end_turn"}) == null)
	assert(battle_state.pending_decision != null)

	var rejected_resolution := dispatcher.dispatch_command({
		"type": "select_decision_target",
		"decision_id": &"wrong_decision",
		"target_unit": other_enemy
	}) as DecisionResolutionResult
	assert(rejected_resolution != null)
	assert(
		rejected_resolution.status
		== DecisionResolutionResult.Status.REJECTED_ID
	)
	assert(battle_state.pending_decision.decision_id == decision_id)

	var hp_before := other_enemy.current_hp
	var resolution := dispatcher.dispatch_command({
		"type": "select_decision_target",
		"decision_id": decision_id,
		"target_unit": other_enemy
	}) as DecisionResolutionResult
	assert(resolution != null)
	assert(resolution.was_resolved(), resolution.message)
	assert(battle_state.pending_decision == null)
	assert(other_enemy.current_hp == hp_before - 2)
	assert(
		execution.impact_execution_result.reaction_execution_results.size()
		== 1
	)

	var reaction_result := (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)
	assert(reaction_result.magnitude_applied == 2)
	assert(reaction_result.impact.source_unit == penitent)
	assert(reaction_result.impact.target_unit == other_enemy)
	assert(
		reaction_result.impact.source_ability_data
		== (load(LAST_STEP_PATH) as UnitAbilityData)
	)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 5)
	assert(event_log.history[0].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[1].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(event_log.history[2].kind == CombatEvent.Kind.DEATH_CONFIRMED)
	assert(event_log.history[2].target_cell_x == 1)
	assert(event_log.history[2].target_cell_y == 2)
	assert(event_log.history[3].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[3].source_unit == penitent)
	assert(event_log.history[4].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(battle_state.check_victory_condition())
	assert(battle_state.winner_team_id == 1)

	_free_pipeline_bundle(bundle)


func _test_last_step_uses_normal_defense_rules() -> void:
	var battle_state := _make_battle_state()
	var attacker_data := _make_unit_data("defended_killer", "Defended", 10, 20)
	attacker_data.active_abilities.append(
		load(MELEE_STRIKE_PATH) as UnitAbilityData
	)
	var attacker := battle_state.spawn_unit(attacker_data, 1, 0, 2)
	var penitent := battle_state.spawn_unit(
		load(PENITENT_PATH) as UnitData,
		2,
		1,
		2
	)
	attacker.active_defenses.append("physical")
	battle_state.set_active_unit(attacker)
	attacker.start_round(1)
	attacker.start_activation(1, 0)
	penitent.start_round(1)

	var bundle := _make_pipeline_bundle(battle_state)
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		attacker,
		penitent,
		attacker.active_abilities[0],
		penitent.cell
	)
	assert(execution.was_committed())
	assert(battle_state.pending_decision != null)
	var hp_before := attacker.current_hp
	var resolution := (
		bundle["command_dispatcher"] as CommandDispatcher
	).dispatch_command({
		"type": "select_decision_target",
		"decision_id": battle_state.pending_decision.decision_id,
		"target_unit": attacker
	}) as DecisionResolutionResult
	assert(resolution.was_resolved())
	assert(attacker.current_hp == hp_before)
	assert(not attacker.active_defenses.has("physical"))

	var blocked_result := (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)
	assert(blocked_result.outcome == ImpactResult.Outcome.BLOCKED_DEFENSE)
	assert(blocked_result.interaction_resolution.armor_was_checked == false)

	_free_pipeline_bundle(bundle)


func _test_last_step_skips_without_adjacent_target() -> void:
	var battle_state := _make_battle_state()
	var attacker := battle_state.spawn_unit(
		_make_unit_data("far_killer", "Far Killer", 10, 20),
		1,
		0,
		2
	)
	var penitent := battle_state.spawn_unit(
		load(PENITENT_PATH) as UnitData,
		2,
		6,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var execution := _execute_damage_plan(
		bundle["impact_executor"] as ImpactExecutor,
		battle_state,
		&"far_lethal_execution",
		attacker,
		penitent,
		4,
		Impact.InteractionType.RANGED
	)
	assert(execution.is_successful())
	assert(penitent.is_dead())
	assert(penitent.cell == null)
	assert(battle_state.pending_decision == null)
	assert(execution.reaction_execution_results.is_empty())
	assert(battle_state.check_victory_condition())
	assert(battle_state.winner_team_id == 1)

	_free_pipeline_bundle(bundle)


# ============================================================
# ПАУЗА В КОНЦЕ АКТИВАЦИИ
# ============================================================

func _test_activation_end_pauses_and_resumes_after_choice() -> void:
	var battle_state := _make_battle_state()
	var hunter_data := _make_unit_data("hunter", "Hunter", 10, 100)
	hunter_data.active_abilities.append(
		load(POISONING_DART_PATH) as UnitAbilityData
	)
	var hunter := battle_state.spawn_unit(hunter_data, 1, 0, 2)
	var penitent := battle_state.spawn_unit(
		load(PENITENT_PATH) as UnitData,
		2,
		1,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var turn_pipeline := bundle["turn_pipeline"] as TurnPipeline
	turn_pipeline.start_battle_flow()
	assert(battle_state.active_unit == hunter)

	var dart_execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		hunter,
		penitent,
		hunter.active_abilities[0],
		penitent.cell
	)
	assert(dart_execution.was_committed())
	assert(penitent.current_hp == 1)
	assert(penitent.get_active_effect(&"status.decay") != null)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == penitent)
	var activation_index_before := battle_state.turn_state.current_activation_index
	turn_pipeline.end_current_activation()
	assert(penitent.is_dead())
	assert(battle_state.pending_decision != null)
	assert(not battle_state.is_battle_over)
	assert(
		battle_state.turn_state.current_activation_index
		== activation_index_before
	)

	var hunter_hp_before := hunter.current_hp
	var resolution := (
		bundle["command_dispatcher"] as CommandDispatcher
	).dispatch_command({
		"type": "select_decision_target",
		"decision_id": battle_state.pending_decision.decision_id,
		"target_unit": hunter
	}) as DecisionResolutionResult
	assert(resolution.was_resolved())
	assert(hunter.current_hp == hunter_hp_before - 2)
	assert(battle_state.pending_decision == null)
	assert(battle_state.is_battle_over)
	assert(battle_state.winner_team_id == 1)
	assert(battle_state.turn_state.phase == TurnState.Phase.BATTLE_END)

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
	var decision_pipeline := DecisionPipeline.new()
	var pipeline_runner := PipelineRunner.new()
	var command_dispatcher := CommandDispatcher.new()
	var event_queue := EventQueue.new()
	root.add_child(ability_pipeline)
	root.add_child(turn_pipeline)
	root.add_child(decision_pipeline)
	root.add_child(pipeline_runner)
	root.add_child(command_dispatcher)
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
	decision_pipeline.configure(battle_state, impact_executor)
	pipeline_runner.configure(
		ability_pipeline,
		null,
		turn_pipeline,
		event_queue,
		decision_pipeline
	)
	command_dispatcher.configure(battle_state, pipeline_runner)

	return {
		"battle_state": battle_state,
		"ability_pipeline": ability_pipeline,
		"turn_pipeline": turn_pipeline,
		"decision_pipeline": decision_pipeline,
		"pipeline_runner": pipeline_runner,
		"command_dispatcher": command_dispatcher,
		"event_queue": event_queue,
		"impact_executor": impact_executor,
		"status_effect_system": status_effect_system,
		"combat_event_log": event_log
	}


func _execute_damage_plan(
	executor : ImpactExecutor,
	battle_state : BattleState,
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	magnitude : int,
	interaction_type : Impact.InteractionType
) -> ImpactPlanExecutionResult:
	var impact := Impact.create(
		StringName("%s_damage" % execution_id),
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.DAMAGE,
		interaction_type,
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


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	for key in [
		"ability_pipeline",
		"turn_pipeline",
		"decision_pipeline",
		"pipeline_runner",
		"command_dispatcher",
		"event_queue"
	]:
		var node := bundle.get(key, null) as Node

		if node != null:
			node.free()
