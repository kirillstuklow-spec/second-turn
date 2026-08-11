extends SceneTree


const TEST_SEED : int = 20260815

const ASH_HERALD_PATH : String = (
	"res://Resources/Unit/AshHeraldData.tres"
)
const BLACK_SMOKE_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/BlackSmoke.tres"
)
const BLACK_SMOKE_OBJECT_PATH : String = (
	"res://Resources/BattlefieldObjects/BlackSmokeCloud.tres"
)
const SULFUR_OBJECT_PATH : String = (
	"res://Resources/BattlefieldObjects/SulfurCloud.tres"
)
const SULFUR_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/Sulfur.tres"
)
const FIRE_ARROW_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/FireArrow.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract_and_full_square_targeting()
	_test_ranged_defense_is_shared_spatial_and_non_consumable()
	_test_non_ranged_impact_passes_through_smoke()
	_test_blocked_fire_disperses_smoke_but_not_sulfur()
	_test_fire_on_empty_cell_disperses_smoke()
	_test_round_lifetime_ignores_creation_round()

	print(
		"BlackSmokeBattlefieldObjectSmokeTest: PASS — full 3x3 placement, "
		+ "shared non-consumable RANGED defense, ally/enemy symmetry, "
		+ "movement boundary, blocked FIRE dispersal, IMPACT_RESOLVED vs "
		+ "IMPACT_APPLIED separation and two full subsequent rounds"
	)
	quit()


func _test_resource_contract_and_full_square_targeting() -> void:
	var black_smoke := load(BLACK_SMOKE_PATH) as UnitAbilityData
	var object_data := load(
		BLACK_SMOKE_OBJECT_PATH
	) as BattlefieldObjectData
	assert(black_smoke != null)
	assert(object_data != null)
	assert(object_data.get_validation_issues().is_empty())
	assert(object_data.coverage_offsets.size() == 9)
	assert(object_data.lifetime_rounds == 2)
	assert(object_data.provided_defenses == ["ranged"])
	assert(object_data.visual_data != null)
	assert(object_data.triggers.size() == 1)
	assert(
		object_data.triggers[0].event_kind
		== CombatEvent.Kind.IMPACT_RESOLVED
	)
	assert(object_data.triggers[0].source_type_filter == "fire")
	assert(object_data.triggers[0].minimum_applied_amount == 0)
	assert(object_data.triggers[0].consume_object_on_trigger)
	assert(object_data.triggers[0].response_plan_data == null)

	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(black_smoke)
	assert(schema.is_valid, schema.get_summary())
	assert(black_smoke.ability.action_type == AbilityData.ActionType.SUPPORT)
	assert(black_smoke.ability.target_rule_id == "single_cell")
	assert(black_smoke.impact_plan_data.nodes.size() == 1)
	var create_node : ImpactNodeData = black_smoke.impact_plan_data.nodes[0]
	assert(create_node.operation == Impact.Operation.CREATE_OBJECT)
	assert(create_node.interaction_type == Impact.InteractionType.OBJECT)
	assert(create_node.battlefield_object_data == object_data)

	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	assert(herald.get_active_ability_runtime(black_smoke) != null)
	var valid_cells := TargetingService.new().get_valid_selection_cells(
		battle_state,
		herald,
		black_smoke,
		schema.resolved_parameters
	)
	assert(valid_cells.size() == 15)
	assert(valid_cells.has(battle_state.get_cell_at(3, 2)))
	assert(not valid_cells.has(battle_state.get_cell_at(0, 0)))
	assert(not valid_cells.has(battle_state.get_cell_at(6, 4)))
	battle_state.clear()


func _test_ranged_defense_is_shared_spatial_and_non_consumable() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var attacker_team_1 := battle_state.spawn_unit(
		_make_unit_data("smoke_attacker_one", "Smoke Attacker One", 10),
		1,
		0,
		4
	)
	var attacker_team_2 := battle_state.spawn_unit(
		_make_unit_data("smoke_attacker_two", "Smoke Attacker Two", 10),
		2,
		6,
		4
	)
	var ally_data := _make_unit_data(
		"smoke_ally_target",
		"Smoke Ally Target",
		12
	)
	ally_data.defenses = ["ranged"]
	var ally_target := battle_state.spawn_unit(ally_data, 1, 3, 2)
	var enemy_target := battle_state.spawn_unit(
		_make_unit_data("smoke_enemy_target", "Smoke Enemy Target", 12),
		2,
		4,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_black_smoke(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	assert(battle_state.battlefield_objects.size() == 1)
	var smoke : BattlefieldObjectRuntime = (
		battle_state.battlefield_objects[0]
	)
	assert(smoke.covers_cell(ally_target.cell))
	assert(smoke.covers_cell(enemy_target.cell))

	var ally_hp_before := ally_target.current_hp
	var ally_block := _execute_damage(
		bundle,
		attacker_team_2,
		ally_target,
		Impact.InteractionType.RANGED,
		&"physical",
		&"smoke_blocks_ally"
	)
	assert(ally_block.outcome == ImpactResult.Outcome.BLOCKED_DEFENSE)
	assert(ally_block.blocking_battlefield_object == smoke)
	assert(ally_block.consumed_defense == &"")
	assert(ally_target.current_hp == ally_hp_before)
	assert(ally_target.active_defenses.has("ranged"))

	var enemy_hp_before := enemy_target.current_hp
	var first_enemy_block := _execute_damage(
		bundle,
		attacker_team_1,
		enemy_target,
		Impact.InteractionType.RANGED,
		&"physical",
		&"smoke_blocks_enemy_first"
	)
	var second_enemy_block := _execute_damage(
		bundle,
		attacker_team_1,
		enemy_target,
		Impact.InteractionType.RANGED,
		&"physical",
		&"smoke_blocks_enemy_second"
	)
	assert(first_enemy_block.blocking_battlefield_object == smoke)
	assert(second_enemy_block.blocking_battlefield_object == smoke)
	assert(enemy_target.current_hp == enemy_hp_before)
	assert(battle_state.battlefield_objects.has(smoke))

	assert(
		battle_state.move_unit(
			enemy_target,
			battle_state.get_cell_at(6, 3),
			10
		)
	)
	var outside_hit := _execute_damage(
		bundle,
		attacker_team_1,
		enemy_target,
		Impact.InteractionType.RANGED,
		&"physical",
		&"smoke_outside_hit"
	)
	assert(outside_hit.was_applied())
	assert(enemy_target.current_hp == enemy_hp_before - 3)
	assert(ally_target.active_defenses.has("ranged"))
	assert(battle_state.battle_rng.roll_history.is_empty())

	_free_pipeline_bundle(bundle)


func _test_non_ranged_impact_passes_through_smoke() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var attacker := battle_state.spawn_unit(
		_make_unit_data("smoke_magic_attacker", "Smoke Magic Attacker", 10),
		2,
		6,
		4
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("smoke_magic_target", "Smoke Magic Target", 12),
		1,
		3,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_black_smoke(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	var smoke : BattlefieldObjectRuntime = (
		battle_state.battlefield_objects[0]
	)
	var hp_before := target.current_hp
	var magic_result := _execute_damage(
		bundle,
		attacker,
		target,
		Impact.InteractionType.MAGIC,
		&"physical",
		&"smoke_does_not_block_magic"
	)

	assert(magic_result.was_applied())
	assert(target.current_hp == hp_before - 3)
	assert(battle_state.battlefield_objects.has(smoke))

	_free_pipeline_bundle(bundle)


func _test_blocked_fire_disperses_smoke_but_not_sulfur() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var attacker := battle_state.spawn_unit(
		_make_unit_data("smoke_fire_attacker", "Smoke Fire Attacker", 10),
		2,
		6,
		4
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("smoke_fire_target", "Smoke Fire Target", 12),
		1,
		3,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_black_smoke(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	var smoke : BattlefieldObjectRuntime = (
		battle_state.battlefield_objects[0]
	)
	var sulfur := battle_state.create_battlefield_object(
		load(SULFUR_OBJECT_PATH) as BattlefieldObjectData,
		herald,
		load(SULFUR_PATH) as UnitAbilityData,
		&"overlap_sulfur_creation",
		battle_state.get_cell_at(3, 2)
	)
	assert(sulfur != null)
	var hp_before := target.current_hp
	var fire_result := _execute_damage(
		bundle,
		attacker,
		target,
		Impact.InteractionType.RANGED,
		&"fire",
		&"blocked_fire_disperses_smoke"
	)

	assert(fire_result.outcome == ImpactResult.Outcome.BLOCKED_DEFENSE)
	assert(fire_result.blocking_battlefield_object == smoke)
	assert(target.current_hp == hp_before)
	assert(not battle_state.battlefield_objects.has(smoke))
	assert(battle_state.battlefield_objects.has(sulfur))
	assert(sulfur.is_active)
	var event_log := bundle["combat_event_log"] as CombatEventLog
	var resolved_event := _find_event(
		event_log,
		CombatEvent.Kind.IMPACT_RESOLVED,
		&"blocked_fire_disperses_smoke"
	)
	assert(resolved_event != null)
	assert(resolved_event.impact_outcome == &"blocked_defense")
	assert(
		_find_event(
			event_log,
			CombatEvent.Kind.IMPACT_APPLIED,
			&"blocked_fire_disperses_smoke"
		) == null
	)
	assert(_find_removed_event(event_log, smoke) != null)
	assert(_find_triggered_event(event_log, smoke) != null)

	_free_pipeline_bundle(bundle)


func _test_fire_on_empty_cell_disperses_smoke() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var attacker := battle_state.spawn_unit(
		_make_unit_data("smoke_cell_attacker", "Smoke Cell Attacker", 10),
		2,
		6,
		4
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_black_smoke(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	var smoke : BattlefieldObjectRuntime = (
		battle_state.battlefield_objects[0]
	)
	var empty_cell := battle_state.get_cell_at(2, 2)
	assert(empty_cell.is_empty())
	assert(smoke.covers_cell(empty_cell))
	var result := _execute_fire_cell_contact(
		bundle,
		attacker,
		empty_cell,
		&"empty_cell_fire_disperses_smoke"
	)

	assert(result.is_successful(), result.get_summary())
	assert(not battle_state.battlefield_objects.has(smoke))
	var event_log := bundle["combat_event_log"] as CombatEventLog
	assert(
		_find_event(
			event_log,
			CombatEvent.Kind.IMPACT_APPLIED,
			&"empty_cell_fire_disperses_smoke"
		) != null
	)
	assert(
		_find_event(
			event_log,
			CombatEvent.Kind.IMPACT_RESOLVED,
			&"empty_cell_fire_disperses_smoke"
		) != null
	)

	_free_pipeline_bundle(bundle)


func _test_round_lifetime_ignores_creation_round() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_black_smoke(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	var smoke : BattlefieldObjectRuntime = (
		battle_state.battlefield_objects[0]
	)
	var executor := bundle["impact_executor"] as ImpactExecutor

	executor.finish_battlefield_object_round(1, battle_state)
	assert(battle_state.battlefield_objects.has(smoke))
	assert(smoke.remaining_rounds == 2)
	executor.finish_battlefield_object_round(2, battle_state)
	assert(battle_state.battlefield_objects.has(smoke))
	assert(smoke.remaining_rounds == 1)
	executor.finish_battlefield_object_round(3, battle_state)
	assert(not battle_state.battlefield_objects.has(smoke))
	assert(not smoke.is_active)
	var removed_event := _find_removed_event(
		bundle["combat_event_log"] as CombatEventLog,
		smoke
	)
	assert(removed_event != null)
	assert(removed_event.object_removal_reason == &"duration_expired")

	_free_pipeline_bundle(bundle)


func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	battle_state.turn_state.round_number = 1
	return battle_state


func _spawn_ash_herald(
	battle_state : BattleState,
	team_id : int,
	x : int,
	y : int
) -> UnitRuntime:
	return battle_state.spawn_unit(
		load(ASH_HERALD_PATH) as UnitData,
		team_id,
		x,
		y
	)


func _place_black_smoke(
	bundle : Dictionary,
	herald : UnitRuntime,
	anchor_cell : CellRuntime
) -> AbilityExecutionResult:
	var battle_state := bundle["battle_state"] as BattleState
	_prepare_activation(battle_state, herald, 1)
	var smoke_runtime := herald.get_active_ability_runtime(
		load(BLACK_SMOKE_PATH) as UnitAbilityData
	)
	assert(smoke_runtime != null)
	return (bundle["ability_pipeline"] as AbilityPipeline).execute_ability(
		herald,
		anchor_cell.occupying_unit,
		smoke_runtime,
		anchor_cell
	)


func _prepare_activation(
	battle_state : BattleState,
	unit : UnitRuntime,
	activation_serial : int
) -> void:
	battle_state.turn_state.activation_serial = activation_serial
	battle_state.set_active_unit(unit)
	unit.start_round(battle_state.round_number)
	unit.start_activation(battle_state.round_number, activation_serial - 1)


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


func _execute_damage(
	bundle : Dictionary,
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	interaction_type : Impact.InteractionType,
	source_type : StringName,
	impact_id : StringName
) -> ImpactResult:
	var execution_id := StringName("%s_execution" % String(impact_id))
	var impact := Impact.create(
		impact_id,
		execution_id,
		source_unit,
		target_unit,
		target_unit.cell,
		Impact.Operation.DAMAGE,
		interaction_type,
		source_type,
		3,
		0
	)

	if source_type == &"fire":
		impact.source_ability_data = load(FIRE_ARROW_PATH) as UnitAbilityData

	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	var execution := (bundle["impact_executor"] as ImpactExecutor).execute(
		plan,
		BattleStateSnapshot.capture(bundle["battle_state"] as BattleState),
		bundle["battle_state"] as BattleState
	)
	assert(execution.is_successful(), execution.get_summary())
	var result := execution.get_result(impact_id)
	assert(result != null)
	return result


func _execute_fire_cell_contact(
	bundle : Dictionary,
	source_unit : UnitRuntime,
	target_cell : CellRuntime,
	impact_id : StringName
) -> ImpactPlanExecutionResult:
	var execution_id := StringName("%s_execution" % String(impact_id))
	var impact := Impact.create(
		impact_id,
		execution_id,
		source_unit,
		null,
		target_cell,
		Impact.Operation.AFFECT_CELL,
		Impact.InteractionType.CELL,
		&"fire",
		1,
		0
	)
	impact.source_ability_data = load(FIRE_ARROW_PATH) as UnitAbilityData
	var plan := ImpactPlan.create(execution_id, ImpactPlan.Topology.TREE)
	assert(plan.add_root_impact(impact))
	return (bundle["impact_executor"] as ImpactExecutor).execute(
		plan,
		BattleStateSnapshot.capture(bundle["battle_state"] as BattleState),
		bundle["battle_state"] as BattleState
	)


func _find_event(
	event_log : CombatEventLog,
	event_kind : CombatEvent.Kind,
	impact_id : StringName
) -> CombatEvent:
	for event in event_log.history:
		if (
			event != null
			and event.kind == event_kind
			and event.impact_id == impact_id
		):
			return event

	return null


func _find_removed_event(
	event_log : CombatEventLog,
	object_runtime : BattlefieldObjectRuntime
) -> CombatEvent:
	for event in event_log.history:
		if (
			event != null
			and event.kind == CombatEvent.Kind.BATTLEFIELD_OBJECT_REMOVED
			and event.battlefield_object == object_runtime
		):
			return event

	return null


func _find_triggered_event(
	event_log : CombatEventLog,
	object_runtime : BattlefieldObjectRuntime
) -> CombatEvent:
	for event in event_log.history:
		if (
			event != null
			and event.kind == CombatEvent.Kind.BATTLEFIELD_OBJECT_TRIGGERED
			and event.battlefield_object == object_runtime
		):
			return event

	return null


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	var ability_pipeline := bundle.get("ability_pipeline", null) as Node

	if ability_pipeline != null:
		ability_pipeline.free()
