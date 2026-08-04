extends SceneTree


const TEST_SEED : int = 20260804


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_five_interaction_types()
	_test_strict_targeting_and_typed_pipeline_result()
	_test_aoe_uses_fixed_target_snapshot()
	_test_tree_and_queue_interruption_rules()

	print(
		"ImpactPlanAndTargetingSmokeTest: PASS — strict targeting, "
		+ "fixed AoE snapshot, typed results, tree branches and queue interruption"
	)

	quit()


# ============================================================
# ПЯТЬ ТИПОВ ВЗАИМОДЕЙСТВИЯ
# ============================================================

func _test_five_interaction_types() -> void:
	var melee := _make_damage_ability(
		"single_adjacent_enemy",
		AbilityData.TargetingForm.MELEE
	)
	var ranged := _make_damage_ability(
		"single_any_enemy",
		AbilityData.TargetingForm.RANGED
	)
	var magic := _make_damage_ability(
		"single_any_enemy",
		AbilityData.TargetingForm.MAGIC
	)
	var healing := _make_healing_ability()
	var summon_data := AbilityData.new()
	summon_data.action_type = AbilityData.ActionType.SUMMON

	assert(
		Impact.interaction_type_from_ability(melee.ability)
		== Impact.InteractionType.MELEE
	)
	assert(
		Impact.interaction_type_from_ability(ranged.ability)
		== Impact.InteractionType.RANGED
	)
	assert(
		Impact.interaction_type_from_ability(magic.ability)
		== Impact.InteractionType.MAGIC
	)
	assert(
		Impact.interaction_type_from_ability(healing.ability)
		== Impact.InteractionType.HEALING
	)
	assert(
		Impact.interaction_type_from_ability(summon_data)
		== Impact.InteractionType.SUMMON
	)
	assert(
		Impact.get_interaction_type_id(Impact.InteractionType.MELEE)
		== &"melee"
	)
	assert(
		Impact.get_interaction_type_id(Impact.InteractionType.RANGED)
		== &"ranged"
	)
	assert(
		Impact.get_interaction_type_id(Impact.InteractionType.MAGIC)
		== &"magic"
	)
	assert(
		Impact.get_interaction_type_id(Impact.InteractionType.HEALING)
		== &"healing"
	)
	assert(
		Impact.get_interaction_type_id(Impact.InteractionType.SUMMON)
		== &"summon"
	)


# ============================================================
# TARGETING + ТИПИЗИРОВАННЫЙ РЕЗУЛЬТАТ PIPELINE
# ============================================================

func _test_strict_targeting_and_typed_pipeline_result() -> void:
	var ranged_attack := _make_damage_ability(
		"single_any_enemy",
		AbilityData.TargetingForm.RANGED
	)
	ranged_attack.ability.impact_plan_type = (
		AbilityData.ImpactPlanType.QUEUE
	)
	var melee_attack := _make_damage_ability(
		"single_adjacent_enemy",
		AbilityData.TargetingForm.MELEE
	)
	var all_enemies_attack := _make_damage_ability(
		"all_enemies",
		AbilityData.TargetingForm.MAGIC
	)
	var healing := _make_healing_ability()
	var owner_data := _make_unit_data(
		"targeting_owner",
		"Targeting Owner"
	)
	owner_data.active_abilities.append(ranged_attack)
	owner_data.active_abilities.append(melee_attack)
	owner_data.active_abilities.append(healing)

	var ally_data := _make_unit_data(
		"targeting_ally",
		"Targeting Ally"
	)
	var enemy_data := _make_unit_data(
		"targeting_enemy",
		"Targeting Enemy"
	)
	var battle_state := _make_battle_state()
	var owner := battle_state.spawn_unit(owner_data, 1, 0, 2)
	var ally := battle_state.spawn_unit(ally_data, 1, 1, 2)
	var adjacent_enemy := battle_state.spawn_unit(
		enemy_data,
		2,
		0,
		1
	)
	var distant_enemy := battle_state.spawn_unit(
		enemy_data,
		2,
		6,
		2
	)

	assert(owner != null)
	assert(ally != null)
	assert(adjacent_enemy != null)
	assert(distant_enemy != null)

	battle_state.set_active_unit(owner)
	owner.start_round(1)
	owner.start_activation(1, 0)

	var registry := AbilityAlgorithmRegistry.new()
	var targeting := TargetingService.new()
	var ranged_schema := registry.validate_unit_ability(ranged_attack)
	var melee_schema := registry.validate_unit_ability(melee_attack)
	var healing_schema := registry.validate_unit_ability(healing)
	var all_enemies_schema := registry.validate_unit_ability(
		all_enemies_attack
	)

	assert(ranged_schema.is_valid, ranged_schema.get_summary())
	assert(melee_schema.is_valid, melee_schema.get_summary())
	assert(healing_schema.is_valid, healing_schema.get_summary())
	assert(
		all_enemies_schema.is_valid,
		all_enemies_schema.get_summary()
	)

	var ally_attack := targeting.resolve(
		battle_state,
		owner,
		ally,
		ally.cell,
		ranged_attack,
		ranged_schema.resolved_parameters
	)
	assert(not ally_attack.is_valid)
	assert(ally_attack.reason == TargetingResult.Reason.TARGET_NOT_ENEMY)

	var enemy_heal := targeting.resolve(
		battle_state,
		owner,
		distant_enemy,
		distant_enemy.cell,
		healing,
		healing_schema.resolved_parameters
	)
	assert(not enemy_heal.is_valid)
	assert(enemy_heal.reason == TargetingResult.Reason.TARGET_NOT_ALLY)

	var distant_melee := targeting.resolve(
		battle_state,
		owner,
		distant_enemy,
		distant_enemy.cell,
		melee_attack,
		melee_schema.resolved_parameters
	)
	assert(not distant_melee.is_valid)
	assert(
		distant_melee.reason
		== TargetingResult.Reason.TARGET_NOT_ADJACENT
	)

	var mismatched_cell := targeting.resolve(
		battle_state,
		owner,
		distant_enemy,
		ally.cell,
		ranged_attack,
		ranged_schema.resolved_parameters
	)
	assert(not mismatched_cell.is_valid)
	assert(
		mismatched_cell.reason
		== TargetingResult.Reason.TARGET_UNIT_CELL_MISMATCH
	)

	var ally_all_enemies_selection := targeting.resolve(
		battle_state,
		owner,
		ally,
		ally.cell,
		all_enemies_attack,
		all_enemies_schema.resolved_parameters
	)
	assert(not ally_all_enemies_selection.is_valid)
	assert(
		ally_all_enemies_selection.reason
		== TargetingResult.Reason.TARGET_NOT_ENEMY
	)

	var valid_all_enemies_selection := targeting.resolve(
		battle_state,
		owner,
		distant_enemy,
		distant_enemy.cell,
		all_enemies_attack,
		all_enemies_schema.resolved_parameters
	)
	assert(valid_all_enemies_selection.is_valid)
	assert(valid_all_enemies_selection.target_unit_snapshots.size() == 2)

	var melee_cells := targeting.get_valid_selection_cells(
		battle_state,
		owner,
		melee_attack,
		melee_schema.resolved_parameters
	)
	assert(melee_cells.size() == 1)
	assert(melee_cells[0] == adjacent_enemy.cell)

	var healing_cells := targeting.get_valid_selection_cells(
		battle_state,
		owner,
		healing,
		healing_schema.resolved_parameters
	)
	assert(healing_cells.has(owner.cell))
	assert(healing_cells.has(ally.cell))
	assert(not healing_cells.has(distant_enemy.cell))

	var availability := AbilityAvailabilityService.new(registry)
	var pipeline := AbilityPipeline.new()
	root.add_child(pipeline)
	pipeline.configure(
		battle_state,
		availability,
		registry,
		targeting
	)

	var ap_before_rejection := owner.action_points_remaining
	var rejected_result := pipeline.execute_ability(
		owner,
		ally,
		owner.active_abilities[0],
		ally.cell
	)

	assert(rejected_result != null)
	assert(not rejected_result.was_committed())
	assert(
		rejected_result.status
		== AbilityExecutionResult.Status.REJECTED_TARGET
	)
	assert(owner.action_points_remaining == ap_before_rejection)
	assert(owner.active_abilities[0].uses_this_battle == 0)

	var enemy_hp_before := distant_enemy.current_hp
	var committed_result := pipeline.execute_ability(
		owner,
		distant_enemy,
		owner.active_abilities[0],
		distant_enemy.cell
	)

	assert(committed_result != null)
	assert(committed_result.was_committed())
	assert(committed_result.execution_id != &"")
	assert(
		committed_result.impact_plan.topology
		== ImpactPlan.Topology.QUEUE
	)
	assert(committed_result.get_impact_results().size() == 1)
	assert(
		committed_result.get_impact_results()[0].was_applied()
	)
	assert(distant_enemy.current_hp == enemy_hp_before - 3)
	assert(owner.action_points_remaining == 0)
	assert(owner.active_abilities[0].uses_this_battle == 1)

	ally.take_damage(4)
	owner.action_points_remaining = 1
	var ally_hp_before_heal := ally.current_hp
	var healing_result := pipeline.execute_ability(
		owner,
		ally,
		owner.active_abilities[2],
		ally.cell
	)

	assert(healing_result.was_committed())
	assert(healing_result.get_impact_results().size() == 1)
	assert(
		healing_result.impact_plan.impacts[0].interaction_type
		== Impact.InteractionType.HEALING
	)
	assert(ally.current_hp == ally_hp_before_heal + 3)
	assert(owner.action_points_remaining == 0)
	assert(owner.active_abilities[2].uses_this_battle == 1)

	battle_state.clear()
	pipeline.free()


# ============================================================
# ФИКСИРОВАННЫЙ СНИМОК AOE
# ============================================================

func _test_aoe_uses_fixed_target_snapshot() -> void:
	var aoe := _make_damage_ability(
		"area_around_cell",
		AbilityData.TargetingForm.MAGIC,
		1
	)
	var owner_data := _make_unit_data(
		"aoe_owner",
		"AoE Owner"
	)
	owner_data.active_abilities.append(aoe)
	var enemy_data := _make_unit_data(
		"aoe_enemy",
		"AoE Enemy"
	)
	var late_enemy_data := _make_unit_data(
		"aoe_late_enemy",
		"Late AoE Enemy"
	)
	var battle_state := _make_battle_state()
	var owner := battle_state.spawn_unit(owner_data, 1, 0, 2)
	var upper_enemy := battle_state.spawn_unit(enemy_data, 2, 5, 1)
	var left_enemy := battle_state.spawn_unit(enemy_data, 2, 4, 2)
	var right_enemy := battle_state.spawn_unit(enemy_data, 2, 6, 2)
	var center_cell := battle_state.get_cell_at(5, 2)

	assert(owner != null)
	assert(upper_enemy != null)
	assert(left_enemy != null)
	assert(right_enemy != null)
	assert(center_cell != null)

	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(aoe)
	assert(schema.is_valid, schema.get_summary())

	var targeting := TargetingService.new()
	var target_result := targeting.resolve(
		battle_state,
		owner,
		null,
		center_cell,
		aoe,
		schema.resolved_parameters
	)

	assert(target_result.is_valid, target_result.get_summary())
	assert(target_result.target_unit_snapshots.size() == 3)
	assert(target_result.target_unit_snapshots[0].unit == upper_enemy)
	assert(target_result.target_unit_snapshots[1].unit == left_enemy)
	assert(target_result.target_unit_snapshots[2].unit == right_enemy)

	var build_result := AbilityImpactPlanBuilder.new().build(
		&"aoe_snapshot_execution",
		owner,
		owner.active_abilities[0],
		target_result,
		schema.resolved_parameters
	)
	assert(build_result.is_valid, build_result.message)
	assert(build_result.plan.impacts.size() == 3)
	assert(build_result.plan.topology == ImpactPlan.Topology.TREE)

	# Юнит появляется после определения набора целей. Он не должен
	# попасть в уже созданный ImpactPlan.
	var late_enemy := battle_state.spawn_unit(
		late_enemy_data,
		2,
		5,
		2
	)
	assert(late_enemy != null)

	var original_targets : Array[UnitRuntime] = [
		upper_enemy,
		left_enemy,
		right_enemy
	]
	var hp_before : Dictionary = {}

	for original_target in original_targets:
		hp_before[original_target] = original_target.current_hp

	var late_hp_before := late_enemy.current_hp
	var execution_result := ImpactExecutor.new().execute(
		build_result.plan,
		target_result.snapshot,
		battle_state
	)

	assert(execution_result.is_successful())
	assert(execution_result.impact_results.size() == 3)

	for original_target in original_targets:
		assert(
			original_target.current_hp
			== int(hp_before[original_target]) - 3
		)

	assert(late_enemy.current_hp == late_hp_before)
	battle_state.clear()


# ============================================================
# ДЕРЕВО И ОЧЕРЕДЬ
# ============================================================

func _test_tree_and_queue_interruption_rules() -> void:
	_test_tree_keeps_independent_branches()
	_test_queue_stops_after_interruption()


func _test_tree_keeps_independent_branches() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("tree_source", "Tree Source"),
		1,
		0,
		2
	)
	var immune_data := _make_unit_data(
		"tree_immune",
		"Tree Immune"
	)
	immune_data.immunities = ["physical"]
	var blocked_target := battle_state.spawn_unit(
		immune_data,
		2,
		4,
		2
	)
	var child_target := battle_state.spawn_unit(
		_make_unit_data("tree_child", "Tree Child"),
		2,
		5,
		2
	)
	var independent_target := battle_state.spawn_unit(
		_make_unit_data("tree_sibling", "Tree Sibling"),
		2,
		6,
		2
	)

	var snapshot := BattleStateSnapshot.capture(battle_state)
	var plan := ImpactPlan.create(
		&"tree_execution",
		ImpactPlan.Topology.TREE
	)
	var blocked_root := _make_impact(
		&"tree_blocked_root",
		plan.execution_id,
		source,
		blocked_target,
		2
	)
	blocked_root.order_index = 0
	var skipped_child := _make_impact(
		&"tree_skipped_child",
		plan.execution_id,
		source,
		child_target,
		2
	)
	skipped_child.order_index = 1
	var independent_root := _make_impact(
		&"tree_independent_root",
		plan.execution_id,
		source,
		independent_target,
		2
	)
	independent_root.order_index = 2

	assert(plan.add_root_impact(blocked_root))
	assert(plan.add_child_impact(
		blocked_root.impact_id,
		skipped_child
	))
	assert(plan.add_root_impact(independent_root))
	assert(skipped_child.source_object == source)

	var child_hp_before := child_target.current_hp
	var sibling_hp_before := independent_target.current_hp
	var result := ImpactExecutor.new().execute(
		plan,
		snapshot,
		battle_state
	)

	assert(result.is_successful())
	assert(
		result.get_result(blocked_root.impact_id).outcome
		== ImpactResult.Outcome.BLOCKED_IMMUNITY
	)
	assert(
		result.get_result(skipped_child.impact_id).outcome
		== ImpactResult.Outcome.SKIPPED_PARENT
	)
	assert(
		result.get_result(independent_root.impact_id).outcome
		== ImpactResult.Outcome.APPLIED
	)
	assert(child_target.current_hp == child_hp_before)
	assert(independent_target.current_hp == sibling_hp_before - 2)
	battle_state.clear()


func _test_queue_stops_after_interruption() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("queue_source", "Queue Source"),
		1,
		0,
		2
	)
	var first_target := battle_state.spawn_unit(
		_make_unit_data("queue_first", "Queue First"),
		2,
		4,
		2
	)
	var immune_data := _make_unit_data(
		"queue_immune",
		"Queue Immune"
	)
	immune_data.immunities = ["physical"]
	var interrupting_target := battle_state.spawn_unit(
		immune_data,
		2,
		5,
		2
	)
	var skipped_target := battle_state.spawn_unit(
		_make_unit_data("queue_skipped", "Queue Skipped"),
		2,
		6,
		2
	)
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var plan := ImpactPlan.create(
		&"queue_execution",
		ImpactPlan.Topology.QUEUE
	)
	var first := _make_impact(
		&"queue_first_impact",
		plan.execution_id,
		source,
		first_target,
		2
	)
	var interrupting := _make_impact(
		&"queue_interrupting_impact",
		plan.execution_id,
		source,
		interrupting_target,
		2
	)
	var skipped := _make_impact(
		&"queue_skipped_impact",
		plan.execution_id,
		source,
		skipped_target,
		2
	)
	first.order_index = 0
	interrupting.order_index = 1
	skipped.order_index = 2
	assert(plan.append_queue_impact(first))
	assert(plan.append_queue_impact(interrupting))
	assert(plan.append_queue_impact(skipped))

	var first_hp_before := first_target.current_hp
	var skipped_hp_before := skipped_target.current_hp
	var result := ImpactExecutor.new().execute(
		plan,
		snapshot,
		battle_state
	)

	assert(result.is_successful())
	assert(
		result.get_result(first.impact_id).outcome
		== ImpactResult.Outcome.APPLIED
	)
	assert(
		result.get_result(interrupting.impact_id).outcome
		== ImpactResult.Outcome.BLOCKED_IMMUNITY
	)
	assert(
		result.get_result(skipped.impact_id).outcome
		== ImpactResult.Outcome.SKIPPED_QUEUE_INTERRUPTED
	)
	assert(first_target.current_hp == first_hp_before - 2)
	assert(skipped_target.current_hp == skipped_hp_before)
	battle_state.clear()


# ============================================================
# FIXTURES
# ============================================================

func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	return battle_state


func _make_damage_ability(
	target_rule_id : String,
	targeting_form : AbilityData.TargetingForm,
	radius : int = -1
) -> UnitAbilityData:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Impact smoke damage"
	mechanism.action_type = AbilityData.ActionType.ATTACK
	mechanism.targeting_form = targeting_form
	mechanism.algorithm_id = "deal_damage"
	mechanism.target_rule_id = target_rule_id
	mechanism.default_conditions = [
		"target_must_be_alive",
		"target_must_be_enemy"
	]
	mechanism.default_parameters = {
		"armor_penetration": 0,
		"keyword": "physical"
	}

	if radius >= 0:
		mechanism.default_parameters["radius"] = radius

	var unit_ability := UnitAbilityData.new()
	unit_ability.ability_name = "Impact smoke attack"
	unit_ability.ability = mechanism
	unit_ability.parameters = {
		"damage": 3
	}
	return unit_ability


func _make_healing_ability() -> UnitAbilityData:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Impact smoke healing"
	mechanism.action_type = AbilityData.ActionType.HEAL
	mechanism.targeting_form = AbilityData.TargetingForm.RANGED
	mechanism.algorithm_id = "heal_target"
	mechanism.target_rule_id = "single_any_ally"
	mechanism.default_conditions = [
		"target_must_be_alive",
		"target_must_be_ally"
	]

	var unit_ability := UnitAbilityData.new()
	unit_ability.ability_name = "Impact smoke healing"
	unit_ability.ability = mechanism
	unit_ability.parameters = {
		"heal": 3
	}
	return unit_ability


func _make_unit_data(
	unit_id : String,
	unit_name : String
) -> UnitData:
	var unit_data := UnitData.new()
	unit_data.unit_id = unit_id
	unit_data.unit_name = unit_name
	unit_data.max_hp = 10
	unit_data.armor = 0
	unit_data.initiative = 0
	return unit_data


func _make_impact(
	impact_id : StringName,
	execution_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	magnitude : int
) -> Impact:
	return Impact.create(
		impact_id,
		execution_id,
		source,
		target,
		target.cell,
		Impact.Operation.DAMAGE,
		Impact.InteractionType.RANGED,
		&"physical",
		magnitude,
		0
	)
