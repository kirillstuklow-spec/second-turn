extends SceneTree


const TEST_SEED : int = 20260813

const ASH_HERALD_PATH : String = (
	"res://Resources/Unit/AshHeraldData.tres"
)
const FIRESTARTER_PATH : String = (
	"res://Resources/Unit/FirestarterData.tres"
)
const SULFUR_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/Sulfur.tres"
)
const FIRE_ARROW_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/FireArrow.tres"
)
const SULFUR_OBJECT_PATH : String = (
	"res://Resources/BattlefieldObjects/SulfurCloud.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_resource_contract_and_full_square_targeting()
	_test_placement_and_activation_end_damage()
	_test_applied_fire_explodes_and_burns_all_units_inside()
	_test_fire_contact_on_empty_covered_cell_explodes()
	_test_blocked_fire_does_not_trigger_object()
	_test_round_lifetime_ignores_creation_round()

	print(
		"SulfurBattlefieldObjectSmokeTest: PASS — Data → Runtime → View "
		+ "contract, full 3x3 placement, activation-end poison, applied "
		+ "FIRE spatial trigger, all-unit explosion, Burning, removal and "
		+ "two full subsequent rounds of lifetime"
	)
	quit()


func _test_resource_contract_and_full_square_targeting() -> void:
	var sulfur := load(SULFUR_PATH) as UnitAbilityData
	var object_data := load(SULFUR_OBJECT_PATH) as BattlefieldObjectData
	assert(sulfur != null)
	assert(object_data != null)
	assert(object_data.get_validation_issues().is_empty())
	assert(object_data.coverage_offsets.size() == 9)
	assert(object_data.lifetime_rounds == 2)
	assert(object_data.triggers.size() == 2)
	assert(
		object_data.triggers[0].event_kind
		== CombatEvent.Kind.ACTIVATION_ENDED
	)
	assert(
		object_data.triggers[1].event_kind
		== CombatEvent.Kind.IMPACT_APPLIED
	)
	assert(object_data.triggers[1].source_type_filter == "fire")
	assert(object_data.triggers[1].consume_object_on_trigger)

	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(sulfur)
	assert(schema.is_valid, schema.get_summary())
	assert(sulfur.ability.action_type == AbilityData.ActionType.SUPPORT)
	assert(sulfur.ability.target_rule_id == "single_cell")
	assert(sulfur.impact_plan_data.nodes.size() == 1)
	var create_node : ImpactNodeData = sulfur.impact_plan_data.nodes[0]
	assert(create_node.operation == Impact.Operation.CREATE_OBJECT)
	assert(create_node.interaction_type == Impact.InteractionType.OBJECT)
	assert(create_node.battlefield_object_data == object_data)
	assert(
		ImpactPlanDataValidator.validate(
			object_data.triggers[0].response_plan_data
		).is_empty()
	)
	assert(
		ImpactPlanDataValidator.validate(
			object_data.triggers[1].response_plan_data
		).is_empty()
	)

	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var targeting := TargetingService.new()
	var valid_cells := targeting.get_valid_selection_cells(
		battle_state,
		herald,
		sulfur,
		schema.resolved_parameters
	)
	assert(valid_cells.size() == 15)
	assert(valid_cells.has(battle_state.get_cell_at(3, 2)))
	assert(not valid_cells.has(battle_state.get_cell_at(0, 0)))
	assert(not valid_cells.has(battle_state.get_cell_at(6, 4)))
	battle_state.clear()


func _test_placement_and_activation_end_damage() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var inside := battle_state.spawn_unit(
		_make_unit_data("inside_periodic", "Inside Periodic", 10),
		2,
		3,
		2
	)
	var outside := battle_state.spawn_unit(
		_make_unit_data("outside_periodic", "Outside Periodic", 10),
		2,
		6,
		4
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_sulfur(bundle, herald, battle_state.get_cell_at(3, 2))
	assert(placement.was_committed(), placement.message)
	assert(battle_state.battlefield_objects.size() == 1)

	var object_runtime := battle_state.battlefield_objects[0]
	assert(object_runtime.covered_cells.size() == 9)
	assert(object_runtime.anchor_cell == battle_state.get_cell_at(3, 2))
	assert(object_runtime.covers_cell(inside.cell))
	assert(not object_runtime.covers_cell(outside.cell))
	assert(inside.cell.covering_objects.has(object_runtime))
	assert(not inside.cell.is_empty())
	var covered_movement_cell := battle_state.get_cell_at(2, 1)
	assert(object_runtime.covers_cell(covered_movement_cell))
	assert(covered_movement_cell.is_empty())
	assert(
		battle_state.can_unit_move_to(
			herald,
			covered_movement_cell,
			3
		)
	)

	var battlefield_view := _make_battlefield_view()
	battlefield_view.draw_battlefield(battle_state)
	assert(battlefield_view.temporary_objects_root != null)
	assert(
		battlefield_view.temporary_objects_root.get_child_count() == 10
	)
	battlefield_view.free()

	var executor := bundle["impact_executor"] as ImpactExecutor
	var inside_hp_before := inside.current_hp
	var inside_event_result := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		inside,
		battle_state
	)
	assert(inside_event_result.is_successful())
	assert(inside.current_hp == inside_hp_before - 1)
	assert(inside_event_result.reaction_execution_results.size() == 1)
	var poison_result : ImpactResult = (
		inside_event_result.reaction_execution_results[0].impact_results[0]
	)
	assert(poison_result.magnitude_applied == 1)
	assert(poison_result.impact.source_object == object_runtime)
	assert(poison_result.impact.interaction_type == Impact.InteractionType.EFFECT)
	assert(poison_result.impact.source_type == &"decay")

	var outside_hp_before := outside.current_hp
	var outside_event_result := executor.process_unit_event(
		CombatEvent.Kind.ACTIVATION_ENDED,
		outside,
		battle_state
	)
	assert(outside_event_result.is_successful())
	assert(outside.current_hp == outside_hp_before)
	assert(outside_event_result.reaction_execution_results.is_empty())
	assert(battle_state.battlefield_objects.has(object_runtime))

	_free_pipeline_bundle(bundle)


func _test_applied_fire_explodes_and_burns_all_units_inside() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var firestarter := battle_state.spawn_unit(
		load(FIRESTARTER_PATH) as UnitData,
		2,
		6,
		4
	)
	var fire_target := battle_state.spawn_unit(
		_make_unit_data("fire_target", "Fire Target", 12),
		1,
		3,
		2
	)
	var second_unit := battle_state.spawn_unit(
		_make_unit_data("second_inside", "Second Inside", 12),
		2,
		4,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_sulfur(bundle, herald, battle_state.get_cell_at(3, 2))
	assert(placement.was_committed(), placement.message)
	var object_runtime := battle_state.battlefield_objects[0]
	var fire_target_hp_before := fire_target.current_hp
	var second_hp_before := second_unit.current_hp

	_prepare_activation(battle_state, firestarter, 2)
	var fire_arrow_runtime := firestarter.get_active_ability_runtime(
		load(FIRE_ARROW_PATH) as UnitAbilityData
	)
	assert(fire_arrow_runtime != null)
	var fire_execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		firestarter,
		fire_target,
		fire_arrow_runtime,
		fire_target.cell
	)

	assert(fire_execution.was_committed(), fire_execution.message)
	assert(not battle_state.battlefield_objects.has(object_runtime))
	assert(not object_runtime.is_active)
	assert(fire_target.current_hp == fire_target_hp_before - 6)
	assert(second_unit.current_hp == second_hp_before - 2)
	assert(fire_target.get_active_effect(&"status.burning") != null)
	assert(second_unit.get_active_effect(&"status.burning") != null)

	var explosion_result := _find_object_reaction_result(
		fire_execution.impact_execution_result,
		object_runtime
	)
	assert(explosion_result != null)
	assert(explosion_result.impact_results.size() == 4)
	assert(
		explosion_result.impact_results[0].impact.source_object
		== object_runtime
	)
	assert(
		explosion_result.impact_results[0].impact.source_type == &"fire"
	)

	var event_log := bundle["combat_event_log"] as CombatEventLog
	var removed_event := _find_object_removed_event(event_log, object_runtime)
	assert(removed_event != null)
	assert(removed_event.object_removal_reason == &"trigger_consumed")
	assert(
		_has_spatial_fire_event_for_cell(
			event_log,
			battle_state.get_cell_at(3, 2)
		)
	)

	_free_pipeline_bundle(bundle)


func _test_fire_contact_on_empty_covered_cell_explodes() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var firestarter := battle_state.spawn_unit(
		load(FIRESTARTER_PATH) as UnitData,
		2,
		6,
		4
	)
	var victim := battle_state.spawn_unit(
		_make_unit_data("empty_cell_victim", "Empty Cell Victim", 12),
		2,
		4,
		2
	)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_sulfur(
		bundle,
		herald,
		battle_state.get_cell_at(3, 2)
	)
	assert(placement.was_committed(), placement.message)
	var object_runtime := battle_state.battlefield_objects[0]
	var empty_fire_cell := battle_state.get_cell_at(2, 2)
	assert(empty_fire_cell.is_empty())
	assert(object_runtime.covers_cell(empty_fire_cell))
	var victim_hp_before := victim.current_hp

	var impact := Impact.create(
		&"empty_cell_fire_contact",
		&"empty_cell_fire_execution",
		firestarter,
		null,
		empty_fire_cell,
		Impact.Operation.AFFECT_CELL,
		Impact.InteractionType.CELL,
		&"fire",
		1,
		0
	)
	impact.source_ability_data = load(FIRE_ARROW_PATH) as UnitAbilityData
	var plan := ImpactPlan.create(
		&"empty_cell_fire_execution",
		ImpactPlan.Topology.TREE
	)
	assert(plan.add_root_impact(impact))
	var result := (bundle["impact_executor"] as ImpactExecutor).execute(
		plan,
		BattleStateSnapshot.capture(battle_state),
		battle_state
	)

	assert(result.is_successful(), result.get_summary())
	assert(result.impact_results.size() == 1)
	assert(result.impact_results[0].magnitude_applied == 1)
	assert(victim.current_hp == victim_hp_before - 2)
	assert(victim.get_active_effect(&"status.burning") != null)
	assert(not battle_state.battlefield_objects.has(object_runtime))
	assert(
		_has_spatial_fire_event_for_cell(
			bundle["combat_event_log"] as CombatEventLog,
			empty_fire_cell
		)
	)
	assert(_find_object_reaction_result(result, object_runtime) != null)

	_free_pipeline_bundle(bundle)


func _test_blocked_fire_does_not_trigger_object() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var firestarter := battle_state.spawn_unit(
		load(FIRESTARTER_PATH) as UnitData,
		2,
		6,
		4
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("blocked_fire_target", "Blocked Fire Target", 12),
		1,
		3,
		2
	)
	target.active_defenses.append("ranged")
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_sulfur(bundle, herald, battle_state.get_cell_at(3, 2))
	assert(placement.was_committed(), placement.message)
	var object_runtime := battle_state.battlefield_objects[0]
	var hp_before := target.current_hp

	_prepare_activation(battle_state, firestarter, 2)
	var fire_arrow_runtime := firestarter.get_active_ability_runtime(
		load(FIRE_ARROW_PATH) as UnitAbilityData
	)
	var fire_execution := (
		bundle["ability_pipeline"] as AbilityPipeline
	).execute_ability(
		firestarter,
		target,
		fire_arrow_runtime,
		target.cell
	)

	assert(fire_execution.was_committed(), fire_execution.message)
	assert(target.current_hp == hp_before)
	assert(battle_state.battlefield_objects.has(object_runtime))
	assert(object_runtime.is_active)
	assert(
		_find_object_reaction_result(
			fire_execution.impact_execution_result,
			object_runtime
		) == null
	)

	_free_pipeline_bundle(bundle)


func _test_round_lifetime_ignores_creation_round() -> void:
	var battle_state := _make_battle_state()
	var herald := _spawn_ash_herald(battle_state, 1, 0, 0)
	var bundle := _make_pipeline_bundle(battle_state)
	var placement := _place_sulfur(bundle, herald, battle_state.get_cell_at(3, 2))
	assert(placement.was_committed(), placement.message)
	var object_runtime := battle_state.battlefield_objects[0]
	var executor := bundle["impact_executor"] as ImpactExecutor

	executor.finish_battlefield_object_round(1, battle_state)
	assert(battle_state.battlefield_objects.has(object_runtime))
	assert(object_runtime.remaining_rounds == 2)
	executor.finish_battlefield_object_round(2, battle_state)
	assert(battle_state.battlefield_objects.has(object_runtime))
	assert(object_runtime.remaining_rounds == 1)
	executor.finish_battlefield_object_round(3, battle_state)
	assert(not battle_state.battlefield_objects.has(object_runtime))
	assert(not object_runtime.is_active)

	var removed_event := _find_object_removed_event(
		bundle["combat_event_log"] as CombatEventLog,
		object_runtime
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


func _place_sulfur(
	bundle : Dictionary,
	herald : UnitRuntime,
	anchor_cell : CellRuntime
) -> AbilityExecutionResult:
	var battle_state := bundle["battle_state"] as BattleState
	_prepare_activation(battle_state, herald, 1)
	var sulfur_runtime := herald.get_active_ability_runtime(
		load(SULFUR_PATH) as UnitAbilityData
	)
	assert(sulfur_runtime != null)
	return (bundle["ability_pipeline"] as AbilityPipeline).execute_ability(
		herald,
		anchor_cell.occupying_unit,
		sulfur_runtime,
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


func _make_battlefield_view() -> BattlefieldView:
	var battlefield_view := BattlefieldView.new()
	var cells_root := Node2D.new()
	cells_root.name = "Cells"
	battlefield_view.add_child(cells_root)
	var units_root := Node2D.new()
	units_root.name = "Units"
	battlefield_view.add_child(units_root)
	var objects_root := Node2D.new()
	objects_root.name = "TemporaryObjects"
	battlefield_view.add_child(objects_root)
	root.add_child(battlefield_view)
	return battlefield_view


func _find_object_reaction_result(
	root_result : ImpactPlanExecutionResult,
	object_runtime : BattlefieldObjectRuntime
) -> ImpactPlanExecutionResult:
	if root_result == null:
		return null

	for reaction_result in root_result.reaction_execution_results:
		if reaction_result == null:
			continue

		for impact_result in reaction_result.impact_results:
			if (
				impact_result != null
				and impact_result.impact != null
				and impact_result.impact.source_object == object_runtime
			):
				return reaction_result

	return null


func _find_object_removed_event(
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


func _has_spatial_fire_event_for_cell(
	event_log : CombatEventLog,
	target_cell : CellRuntime
) -> bool:
	for event in event_log.history:
		if (
			event != null
			and event.kind == CombatEvent.Kind.IMPACT_APPLIED
			and event.source_type == &"fire"
			and event.target_cell == target_cell
		):
			return true

	return false


func _free_pipeline_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState

	if battle_state != null:
		battle_state.clear()

	var ability_pipeline := bundle.get("ability_pipeline", null) as Node

	if ability_pipeline != null:
		ability_pipeline.free()
