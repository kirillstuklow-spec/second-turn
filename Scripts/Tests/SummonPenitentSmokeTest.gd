extends SceneTree


const TEST_SEED : int = 20260809

const HANDLER_PATH : String = (
	"res://Resources/Unit/PenitentHandlerData.tres"
)
const PENITENT_PATH : String = (
	"res://Resources/Unit/PenitentData.tres"
)
const SUMMON_ABILITY_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/SummonPenitent.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract()
	_test_team_2_uses_its_own_deployment_zone()
	_test_targeting_execution_event_and_next_round_queue()
	_test_summoned_unit_prevents_defeat()

	print(
		"SummonPenitentSmokeTest: PASS — declarative SUMMON Impact, "
		+ "both teams' empty deployment-cell targeting, independent allied "
		+ "UnitRuntime, summon provenance, UNIT_SUMMONED event, no "
		+ "current-round activation, next-round initiative and summoned "
		+ "living units preventing defeat"
	)
	quit()


# ============================================================
# РЕСУРСНЫЙ КОНТРАКТ
# ============================================================

func _test_resource_contract() -> void:
	var handler_data := load(HANDLER_PATH) as UnitData
	var penitent_data := load(PENITENT_PATH) as UnitData
	var summon_ability := load(SUMMON_ABILITY_PATH) as UnitAbilityData
	assert(handler_data != null)
	assert(penitent_data != null)
	assert(summon_ability != null)
	assert(handler_data.unit_id == "penitent_handler_test")
	assert(handler_data.unit_name == "Погонщик")
	assert(handler_data.initiative == 35)
	assert(handler_data.max_hp == 10)
	assert(handler_data.armor == 0)
	assert(handler_data.movement == 2)
	assert(handler_data.active_abilities.size() == 1)
	assert(handler_data.active_abilities[0] == summon_ability)
	assert(summon_ability.action_point_cost == 1)
	assert(summon_ability.cooldown_rounds == 0)
	assert(summon_ability.max_charges == 0)
	assert(summon_ability.max_uses_per_battle == 0)
	assert(summon_ability.impact_plan_data != null)
	assert(summon_ability.impact_plan_data.nodes.size() == 1)

	var mechanism := summon_ability.ability
	assert(mechanism != null)
	assert(mechanism.activation_mode == AbilityData.ActivationMode.ACTIVE)
	assert(mechanism.action_type == AbilityData.ActionType.SUMMON)
	assert(mechanism.algorithm_id == "execute_impact_plan")
	assert(mechanism.target_rule_id == "single_empty_deployment_cell")

	var summon_node := summon_ability.impact_plan_data.nodes[0]
	assert(summon_node.operation == Impact.Operation.SUMMON)
	assert(summon_node.interaction_type == Impact.InteractionType.SUMMON)
	assert(summon_node.magnitude == 1)
	assert(summon_node.summon_unit_data == penitent_data)

	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(summon_ability)
	assert(schema.is_valid, schema.get_summary())


# ============================================================
# ЦЕЛЬ, ИСПОЛНЕНИЕ, СОБЫТИЕ И ОЧЕРЕДЬ
# ============================================================

func _test_targeting_execution_event_and_next_round_queue() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		1,
		0,
		1
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("summon_enemy", "Summon Enemy", 10, 15),
		2,
		6,
		1
	)
	assert(handler != null)
	assert(enemy != null)

	var bundle := _make_pipeline_bundle(battle_state)
	var turn_pipeline := bundle["turn_pipeline"] as TurnPipeline
	var ability_pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var targeting := bundle["targeting_service"] as TargetingService
	var registry := bundle["algorithm_registry"] as AbilityAlgorithmRegistry
	turn_pipeline.start_battle_flow()
	assert(battle_state.round_number == 1)
	assert(battle_state.active_unit == handler)

	var summon_runtime := handler.active_abilities[0]
	var schema := registry.validate_unit_ability(summon_runtime.data)
	assert(schema.is_valid, schema.get_summary())
	var own_free_cell := battle_state.get_cell_at(1, 1)
	var enemy_free_cell := battle_state.get_cell_at(5, 2)
	assert(own_free_cell != null)
	assert(enemy_free_cell != null)

	var valid_cells := targeting.get_valid_selection_cells(
		battle_state,
		handler,
		summon_runtime.data,
		schema.resolved_parameters
	)
	assert(valid_cells.size() == 5)
	assert(valid_cells.has(own_free_cell))
	assert(not valid_cells.has(handler.cell))
	assert(not valid_cells.has(enemy_free_cell))

	var occupied_target := targeting.resolve(
		battle_state,
		handler,
		null,
		handler.cell,
		summon_runtime.data,
		schema.resolved_parameters
	)
	assert(not occupied_target.is_valid)
	assert(occupied_target.reason == TargetingResult.Reason.TARGET_CELL_OCCUPIED)

	var wrong_zone_target := targeting.resolve(
		battle_state,
		handler,
		null,
		enemy_free_cell,
		summon_runtime.data,
		schema.resolved_parameters
	)
	assert(not wrong_zone_target.is_valid)
	assert(wrong_zone_target.reason == TargetingResult.Reason.TARGET_CELL_WRONG_ZONE)
	var ap_before_rejection := handler.action_points_remaining
	var rejected_execution := ability_pipeline.execute_ability(
		handler,
		null,
		summon_runtime,
		enemy_free_cell
	)
	assert(not rejected_execution.was_committed())
	assert(
		rejected_execution.status
		== AbilityExecutionResult.Status.REJECTED_TARGET
	)
	assert(handler.action_points_remaining == ap_before_rejection)
	assert(summon_runtime.uses_this_battle == 0)
	assert(battle_state.units.size() == 2)

	var units_before := battle_state.units.size()
	var execution := ability_pipeline.execute_ability(
		handler,
		null,
		summon_runtime,
		own_free_cell
	)
	assert(execution.was_committed(), execution.message)
	assert(handler.action_points_remaining == 0)
	assert(summon_runtime.uses_this_battle == 1)
	assert(battle_state.units.size() == units_before + 1)
	assert(execution.get_impact_results().size() == 1)

	var summon_result := execution.get_impact_results()[0]
	var summoned := summon_result.summoned_unit
	assert(summon_result.was_applied())
	assert(summon_result.magnitude_applied == 1)
	assert(summoned != null)
	assert(summoned != handler)
	assert(summoned.data == (load(PENITENT_PATH) as UnitData))
	assert(summoned.team_id == handler.team_id)
	assert(summoned.cell == own_free_cell)
	assert(own_free_cell.occupying_unit == summoned)
	assert(summoned.current_hp == summoned.data.max_hp)
	assert(summoned.active_abilities.size() == 1)
	assert(summoned.passive_abilities.size() == 1)
	assert(summoned.active_abilities[0].owner == summoned)
	assert(summoned.passive_abilities[0].owner == summoned)
	assert(summoned.was_summoned_in_battle())
	assert(summoned.summoned_by_unit == handler)
	assert(summoned.summon_source_ability_data == summon_runtime.data)
	assert(summoned.summon_execution_id == execution.execution_id)
	assert(summoned.summoned_round_number == 1)
	var post_summon_snapshot := BattleStateSnapshot.capture(battle_state)
	var summon_snapshot := post_summon_snapshot.get_unit_snapshot(summoned)
	assert(summon_snapshot != null)
	assert(summon_snapshot.was_summoned)
	assert(summon_snapshot.summoned_by_unit == handler)
	assert(summon_snapshot.summon_execution_id == execution.execution_id)

	# Очередь раунда уже зафиксирована до применения способности.
	assert(not battle_state.turn_state.activation_queue.has(summoned))

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 1)
	var summon_event := event_log.history[0]
	assert(summon_event.kind == CombatEvent.Kind.UNIT_SUMMONED)
	assert(summon_event.source_unit == handler)
	assert(summon_event.target_unit == summoned)
	assert(summon_event.target_cell == own_free_cell)
	assert(summon_event.target_cell_x == 1)
	assert(summon_event.target_cell_y == 1)
	assert(summon_event.applied_amount == 1)
	assert(summon_event.interaction_type == Impact.InteractionType.SUMMON)

	turn_pipeline.end_current_activation()
	assert(battle_state.active_unit == enemy)
	turn_pipeline.end_current_activation()
	assert(battle_state.round_number == 2)
	assert(battle_state.turn_state.activation_queue.has(summoned))
	assert(battle_state.active_unit == summoned)
	assert(summoned.action_points_remaining == 1)
	assert(summoned.movement_points_remaining == summoned.data.movement)
	assert(summoned.active_abilities[0].current_round_number == 2)
	assert(summoned.passive_abilities[0].current_round_number == 2)

	_free_pipeline_bundle(bundle)


func _test_team_2_uses_its_own_deployment_zone() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		2,
		6,
		1
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("zone_enemy", "Zone Enemy", 10, 15),
		1,
		0,
		1
	)
	assert(handler != null)
	assert(enemy != null)
	battle_state.set_active_unit(handler)
	handler.start_round(1)
	handler.start_activation(1, 0)

	var registry := AbilityAlgorithmRegistry.new()
	var targeting := TargetingService.new()
	var summon_runtime := handler.active_abilities[0]
	var schema := registry.validate_unit_ability(summon_runtime.data)
	assert(schema.is_valid, schema.get_summary())
	var valid_cells := targeting.get_valid_selection_cells(
		battle_state,
		handler,
		summon_runtime.data,
		schema.resolved_parameters
	)
	assert(valid_cells.size() == 5)
	assert(valid_cells.has(battle_state.get_cell_at(5, 2)))
	assert(not valid_cells.has(battle_state.get_cell_at(1, 2)))
	battle_state.clear()


# ============================================================
# ПОБЕДА УЧИТЫВАЕТ ПРИЗВАННЫХ ЖИВЫХ ЮНИТОВ
# ============================================================

func _test_summoned_unit_prevents_defeat() -> void:
	var battle_state := _make_battle_state()
	var handler := battle_state.spawn_unit(
		load(HANDLER_PATH) as UnitData,
		1,
		0,
		1
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("victory_enemy", "Victory Enemy", 10, 15),
		2,
		6,
		1
	)
	var summoned := battle_state.summon_unit(
		load(PENITENT_PATH) as UnitData,
		handler,
		load(SUMMON_ABILITY_PATH) as UnitAbilityData,
		&"victory_summon_execution",
		battle_state.get_cell_at(1, 1)
	)
	assert(handler != null)
	assert(enemy != null)
	assert(summoned != null)

	handler.take_damage(handler.current_hp)
	assert(handler.confirm_death())
	if handler.cell != null:
		handler.cell.remove_unit()

	assert(battle_state.count_alive_units_for_team(1) == 1)
	assert(not battle_state.check_victory_condition())
	assert(not battle_state.is_battle_over)

	summoned.take_damage(summoned.current_hp)
	assert(summoned.confirm_death())
	if summoned.cell != null:
		summoned.cell.remove_unit()

	assert(battle_state.check_victory_condition())
	assert(battle_state.winner_team_id == 2)


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
		"targeting_service": targeting,
		"algorithm_registry": registry,
		"combat_event_log": event_log
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


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle["battle_state"] as BattleState
	if battle_state != null:
		battle_state.clear()

	for key in ["ability_pipeline", "turn_pipeline", "event_queue"]:
		var node := bundle[key] as Node
		if node != null:
			node.free()
