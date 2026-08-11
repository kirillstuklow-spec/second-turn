extends SceneTree


const TEST_SEED : int = 20260811

const GHOUL_PATH : String = "res://Resources/Unit/GhoulData.tres"
const LEAP_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/GhoulLeap.tres"
)
const BURNING_PATH : String = "res://Resources/Effects/Burning.tres"


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract()
	_test_targeting_cost_movement_and_event()
	_test_health_cost_triggers_burning_after_move()
	_test_last_hp_cannot_pay_cost()
	_test_shared_movement_rules_keep_push_separate()

	print(
		"GhoulLeapSmokeTest: PASS — Ghoul test profile, radius-3 empty-cell "
		+ "targeting, 1 AP + 1 nonlethal HP cost with HEALTH_LOST, "
		+ "post-move Burning reaction, unchanged MP, UNIT_MOVED event and "
		+ "shared BattleState movement "
		+ "rules without a push implementation"
	)
	quit()


# ============================================================
# РЕСУРСНЫЙ КОНТРАКТ
# ============================================================

func _test_resource_contract() -> void:
	var ghoul_data := load(GHOUL_PATH) as UnitData
	var leap := load(LEAP_PATH) as UnitAbilityData
	assert(ghoul_data != null)
	assert(leap != null)
	assert(ghoul_data.unit_id == "ghoul_test")
	assert(ghoul_data.unit_name == "Гуль")
	assert(ghoul_data.initiative == 35)
	assert(ghoul_data.max_hp == 10)
	assert(ghoul_data.armor == 0)
	assert(ghoul_data.movement == 2)
	assert(ghoul_data.active_abilities.size() == 2)
	assert(ghoul_data.active_abilities.has(leap))
	assert(leap.action_point_cost == 1)
	assert(leap.health_point_cost == 1)
	assert(int(leap.parameters.get("radius", 0)) == 3)
	assert(leap.ability != null)
	assert(leap.ability.activation_mode == AbilityData.ActivationMode.ACTIVE)
	assert(leap.ability.action_type == AbilityData.ActionType.MOVEMENT)
	assert(leap.ability.algorithm_id == "execute_impact_plan")
	assert(leap.ability.target_rule_id == "single_empty_cell_in_radius")
	assert(leap.impact_plan_data != null)
	assert(leap.impact_plan_data.nodes.size() == 1)

	var move_node : ImpactNodeData = leap.impact_plan_data.nodes[0]
	assert(move_node.node_id == "ghoul_leap_move")
	assert(move_node.target_reference == ImpactNodeData.TargetReference.ABILITY_SOURCE)
	assert(move_node.operation == Impact.Operation.MOVE)
	assert(move_node.interaction_type == Impact.InteractionType.MOVEMENT)
	assert(move_node.magnitude == 1)

	var schema := AbilityAlgorithmRegistry.new().validate_unit_ability(leap)
	assert(schema.is_valid, schema.get_summary())
	assert(int(schema.resolved_parameters.get("radius", 0)) == 3)


# ============================================================
# ЦЕЛЬ, ЦЕНА, ПЕРЕМЕЩЕНИЕ И СОБЫТИЕ
# ============================================================

func _test_targeting_cost_movement_and_event() -> void:
	var battle_state := _make_battle_state()
	var ghoul := battle_state.spawn_unit(
		load(GHOUL_PATH) as UnitData,
		2,
		3,
		2
	)
	var path_blocker := battle_state.spawn_unit(
		_make_unit_data("leap_path_blocker", "Leap Path Blocker"),
		1,
		4,
		2
	)
	var distant_enemy := battle_state.spawn_unit(
		_make_unit_data("leap_distant_enemy", "Leap Distant Enemy"),
		1,
		0,
		0
	)
	assert(ghoul != null)
	assert(path_blocker != null)
	assert(distant_enemy != null)
	battle_state.set_active_unit(ghoul)
	ghoul.start_round(1)
	ghoul.start_activation(1, 0)

	var bundle := _make_pipeline_bundle(battle_state)
	var registry := bundle["algorithm_registry"] as AbilityAlgorithmRegistry
	var targeting := bundle["targeting_service"] as TargetingService
	var ability_pipeline := bundle["ability_pipeline"] as AbilityPipeline
	var leap_runtime := ghoul.get_active_ability_runtime(
		load(LEAP_PATH) as UnitAbilityData
	)
	assert(leap_runtime != null)
	var schema := registry.validate_unit_ability(leap_runtime.data)
	assert(schema.is_valid, schema.get_summary())

	var leap_destination := battle_state.get_cell_at(6, 2)
	var outside_radius := battle_state.get_cell_at(0, 4)
	var original_cell := ghoul.cell as CellRuntime
	assert(leap_destination != null)
	assert(outside_radius != null)

	var valid_cells := targeting.get_valid_selection_cells(
		battle_state,
		ghoul,
		leap_runtime.data,
		schema.resolved_parameters
	)
	assert(valid_cells.has(leap_destination))
	assert(not valid_cells.has(original_cell))
	assert(not valid_cells.has(path_blocker.cell))
	assert(not valid_cells.has(outside_radius))

	# Прыжок проверяет конечную клетку; промежуточный занятый квадрат не
	# превращает его в обычный пошаговый маршрут.
	assert(path_blocker.cell.x == 4)
	assert(leap_destination.x == 6)

	var occupied_result := targeting.resolve(
		battle_state,
		ghoul,
		path_blocker,
		path_blocker.cell,
		leap_runtime.data,
		schema.resolved_parameters
	)
	assert(not occupied_result.is_valid)
	assert(occupied_result.reason == TargetingResult.Reason.TARGET_CELL_OCCUPIED)

	var far_result := targeting.resolve(
		battle_state,
		ghoul,
		null,
		outside_radius,
		leap_runtime.data,
		schema.resolved_parameters
	)
	assert(not far_result.is_valid)
	assert(far_result.reason == TargetingResult.Reason.TARGET_CELL_OUT_OF_RANGE)

	var ap_before_rejection := ghoul.action_points_remaining
	var hp_before_rejection := ghoul.current_hp
	var rejected := ability_pipeline.execute_ability(
		ghoul,
		null,
		leap_runtime,
		outside_radius
	)
	assert(not rejected.was_committed())
	assert(ghoul.action_points_remaining == ap_before_rejection)
	assert(ghoul.current_hp == hp_before_rejection)
	assert(ghoul.cell == original_cell)

	var mp_before := ghoul.movement_points_remaining
	var execution := ability_pipeline.execute_ability(
		ghoul,
		null,
		leap_runtime,
		leap_destination
	)
	assert(execution.was_committed(), execution.message)
	assert(ghoul.action_points_remaining == 0)
	assert(ghoul.current_hp == hp_before_rejection - 1)
	assert(ghoul.movement_points_remaining == mp_before)
	assert(ghoul.cell == leap_destination)
	assert(original_cell.is_empty())
	assert(execution.get_impact_results().size() == 1)

	var move_result : ImpactResult = execution.get_impact_results()[0]
	assert(move_result.was_applied())
	assert(move_result.movement_from_cell == original_cell)
	assert(move_result.movement_to_cell == leap_destination)
	assert(move_result.magnitude_requested == 1)
	assert(move_result.magnitude_applied == 3)
	assert(move_result.impact.movement_max_distance == 3)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 2)
	var health_loss_event : CombatEvent = event_log.history[0]
	var move_event : CombatEvent = event_log.history[1]
	assert(health_loss_event.kind == CombatEvent.Kind.HEALTH_LOST)
	assert(
		health_loss_event.health_loss_cause
		== CombatEvent.HealthLossCause.ABILITY_COST
	)
	assert(health_loss_event.source_unit == ghoul)
	assert(health_loss_event.target_unit == ghoul)
	assert(health_loss_event.applied_amount == 1)
	assert(health_loss_event.hp_delta == -1)
	assert(
		health_loss_event.interaction_type
		== Impact.InteractionType.MOVEMENT
	)
	assert(move_event.kind == CombatEvent.Kind.UNIT_MOVED)
	assert(move_event.source_unit == ghoul)
	assert(move_event.target_unit == ghoul)
	assert(move_event.source_cell == original_cell)
	assert(move_event.source_cell_x == 3)
	assert(move_event.source_cell_y == 2)
	assert(move_event.target_cell == leap_destination)
	assert(move_event.target_cell_x == 6)
	assert(move_event.target_cell_y == 2)
	assert(move_event.applied_amount == 3)
	assert(move_event.interaction_type == Impact.InteractionType.MOVEMENT)

	_free_pipeline_bundle(bundle)


# ============================================================
# РЕАКЦИЯ НА УТРАТУ HP ОТ ЦЕНЫ
# ============================================================

func _test_health_cost_triggers_burning_after_move() -> void:
	var battle_state := _make_battle_state()
	var ghoul := battle_state.spawn_unit(
		load(GHOUL_PATH) as UnitData,
		1,
		2,
		2
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("leap_burning_source", "Leap Burning Source"),
		2,
		6,
		2
	)
	assert(ghoul != null)
	assert(enemy != null)
	battle_state.set_active_unit(ghoul)
	ghoul.start_round(1)
	ghoul.start_activation(1, 0)

	var burning := EffectRuntime.new()
	burning.setup(
		&"test_leap_burning",
		load(BURNING_PATH) as EffectData,
		enemy,
		null,
		ghoul,
		battle_state.turn_state.activation_serial,
		battle_state.round_number
	)
	ghoul.active_effects.append(burning)

	var bundle := _make_pipeline_bundle(battle_state)
	var leap_runtime := ghoul.get_active_ability_runtime(
		load(LEAP_PATH) as UnitAbilityData
	)
	var destination := battle_state.get_cell_at(5, 2)
	assert(leap_runtime != null)
	assert(destination != null)
	var hp_before := ghoul.current_hp
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		ghoul,
		null,
		leap_runtime,
		destination
	)

	assert(execution.was_committed(), execution.message)
	assert(ghoul.cell == destination)
	assert(ghoul.current_hp == hp_before - 2)
	assert(
		execution.impact_execution_result.reaction_execution_results.size()
		== 1
	)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(event_log.history.size() == 4)
	assert(event_log.history[0].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(
		event_log.history[0].health_loss_cause
		== CombatEvent.HealthLossCause.ABILITY_COST
	)
	assert(event_log.history[1].kind == CombatEvent.Kind.UNIT_MOVED)
	assert(event_log.history[2].kind == CombatEvent.Kind.DAMAGE_APPLIED)
	assert(event_log.history[2].origin_effect_runtime_id == burning.runtime_id)
	assert(event_log.history[3].kind == CombatEvent.Kind.HEALTH_LOST)
	assert(
		event_log.history[3].health_loss_cause
		== CombatEvent.HealthLossCause.DAMAGE
	)

	_free_pipeline_bundle(bundle)


# ============================================================
# ПОСЛЕДНИЙ HP НЕ МОЖЕТ БЫТЬ ЦЕНОЙ
# ============================================================

func _test_last_hp_cannot_pay_cost() -> void:
	var battle_state := _make_battle_state()
	var ghoul := battle_state.spawn_unit(
		load(GHOUL_PATH) as UnitData,
		1,
		2,
		2
	)
	var enemy := battle_state.spawn_unit(
		_make_unit_data("leap_cost_enemy", "Leap Cost Enemy"),
		2,
		6,
		2
	)
	assert(ghoul != null)
	assert(enemy != null)
	battle_state.set_active_unit(ghoul)
	ghoul.start_round(1)
	ghoul.start_activation(1, 0)
	ghoul.current_hp = 1

	var bundle := _make_pipeline_bundle(battle_state)
	var availability_service := (
		bundle["availability_service"] as AbilityAvailabilityService
	)
	var leap_runtime := ghoul.get_active_ability_runtime(
		load(LEAP_PATH) as UnitAbilityData
	)
	assert(leap_runtime != null)
	var availability := availability_service.evaluate(
		battle_state,
		leap_runtime
	)
	assert(not availability.is_available)
	assert(availability.has_reason(
		AbilityAvailabilityReason.Code.INSUFFICIENT_HEALTH_POINTS
	))
	assert(not ghoul.can_spend_health_points(1))

	var original_cell := ghoul.cell as CellRuntime
	var target_cell := battle_state.get_cell_at(4, 2)
	var execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		ghoul,
		null,
		leap_runtime,
		target_cell
	)
	assert(not execution.was_committed())
	assert(ghoul.current_hp == 1)
	assert(ghoul.action_points_remaining == 1)
	assert(ghoul.cell == original_cell)
	assert(leap_runtime.uses_this_battle == 0)

	_free_pipeline_bundle(bundle)


# ============================================================
# ОБЩИЙ МАРШРУТ ДВИЖЕНИЯ И ГРАНИЦА ТОЛЧКА
# ============================================================

func _test_shared_movement_rules_keep_push_separate() -> void:
	var battle_state := _make_battle_state()
	var ghoul := battle_state.spawn_unit(
		load(GHOUL_PATH) as UnitData,
		1,
		2,
		2
	)
	assert(ghoul != null)
	var adjacent := battle_state.get_cell_at(3, 2)
	var distant := battle_state.get_cell_at(5, 2)
	assert(battle_state.can_unit_move_to(ghoul, adjacent))
	assert(not battle_state.can_unit_move_to(ghoul, distant))
	assert(battle_state.can_unit_move_to(ghoul, distant, 3))

	# MOVE использует тот же BattleState.move_unit(). Отдельного push-вызова
	# здесь намеренно нет: толчок получит собственный контракт позже.
	assert(battle_state.move_unit(ghoul, distant, 3))
	assert(ghoul.cell == distant)
	battle_state.clear()


# ============================================================
# ТЕСТОВЫЕ ЗАВИСИМОСТИ
# ============================================================

func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	return battle_state


func _make_unit_data(unit_id : String, unit_name : String) -> UnitData:
	var data := UnitData.new()
	data.unit_id = unit_id
	data.unit_name = unit_name
	data.max_hp = 10
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
		"availability_service": availability,
		"targeting_service": targeting,
		"algorithm_registry": registry,
		"impact_executor": impact_executor,
		"combat_event_log": event_log
	}


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	var ability_pipeline := bundle.get("ability_pipeline", null) as Node

	if ability_pipeline != null:
		ability_pipeline.free()
