extends SceneTree


const TEST_SEED : int = 20260804


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_all_six_interaction_types()
	_test_hierarchy_and_defense_consumption()
	_test_armor_scope_and_penetration()
	_test_healing_source_reaches_impact_plan()

	print(
		"InteractionResolverSmokeTest: PASS — six interaction types, "
		+ "immunity > defense > armor, type > source and penetration -5...5"
	)

	quit()


# ============================================================
# ШЕСТЬ ТИПОВ ВЗАИМОДЕЙСТВИЯ
# ============================================================

func _test_all_six_interaction_types() -> void:
	_assert_type_defense(
		Impact.InteractionType.MELEE,
		Impact.Operation.DAMAGE
	)
	_assert_type_defense(
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE
	)
	_assert_type_defense(
		Impact.InteractionType.MAGIC,
		Impact.Operation.DAMAGE
	)
	_assert_type_defense(
		Impact.InteractionType.HEALING,
		Impact.Operation.HEAL
	)
	_assert_type_defense(
		Impact.InteractionType.SUMMON,
		Impact.Operation.SUMMON
	)
	_assert_type_defense(
		Impact.InteractionType.EFFECT,
		Impact.Operation.DAMAGE
	)


func _assert_type_defense(
	interaction_type : Impact.InteractionType,
	operation : Impact.Operation
) -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("type_source", "Type Source"),
		1,
		0,
		2
	)
	var interaction_tag := Impact.get_interaction_type_id(
		interaction_type
	)
	var target_data := _make_unit_data(
		"type_target",
		"Type Target"
	)
	target_data.defenses = [String(interaction_tag)]
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"type_check",
		source,
		target,
		interaction_type,
		operation,
		&"physical",
		0
	)
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var resolution := InteractionResolver.new().resolve(
		impact,
		snapshot.get_unit_snapshot(target),
		snapshot,
		battle_state.battle_rng
	)

	assert(
		resolution.outcome
		== InteractionResolution.Outcome.BLOCKED_DEFENSE
	)
	assert(
		resolution.stage
		== InteractionResolution.Stage.DEFENSE_INTERACTION_TYPE
	)
	assert(resolution.matched_tag == interaction_tag)
	assert(resolution.defense_to_consume == interaction_tag)
	assert(not resolution.armor_was_checked)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


# ============================================================
# ИЕРАРХИЯ И РАСХОДУЕМАЯ ЗАЩИТА
# ============================================================

func _test_hierarchy_and_defense_consumption() -> void:
	_test_source_immunity_precedes_type_defense()
	_test_type_immunity_precedes_source_immunity()
	_test_type_defense_precedes_source_defense()
	_test_source_defense_is_consumed()
	_test_healing_defense_is_resolved_and_consumed()


func _test_source_immunity_precedes_type_defense() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("immunity_source", "Immunity Source"),
		1,
		0,
		2
	)
	var target_data := _make_unit_data(
		"immunity_target",
		"Immunity Target"
	)
	target_data.immunities = ["fire"]
	target_data.defenses = ["ranged"]
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"source_immunity",
		source,
		target,
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		&"fire",
		0
	)
	var hp_before := target.current_hp
	var execution := _execute_single_impact(
		battle_state,
		impact
	)
	var impact_result := execution.get_result(impact.impact_id)

	assert(
		impact_result.outcome
		== ImpactResult.Outcome.BLOCKED_IMMUNITY
	)
	assert(
		impact_result.interaction_resolution.stage
		== InteractionResolution.Stage.IMMUNITY_SOURCE_TYPE
	)
	assert(target.active_defenses.has("ranged"))
	assert(target.current_hp == hp_before)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _test_type_immunity_precedes_source_immunity() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("type_immunity_source", "Type Immunity Source"),
		1,
		0,
		2
	)
	var target_data := _make_unit_data(
		"type_immunity_target",
		"Type Immunity Target"
	)
	target_data.immunities = ["ranged", "fire"]
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"type_immunity",
		source,
		target,
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		&"fire",
		0
	)
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var resolution := InteractionResolver.new().resolve(
		impact,
		snapshot.get_unit_snapshot(target),
		snapshot,
		battle_state.battle_rng
	)

	assert(
		resolution.stage
		== InteractionResolution.Stage.IMMUNITY_INTERACTION_TYPE
	)
	assert(resolution.matched_tag == &"ranged")

	battle_state.clear()


func _test_type_defense_precedes_source_defense() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("defense_source", "Defense Source"),
		1,
		0,
		2
	)
	var target_data := _make_unit_data(
		"defense_target",
		"Defense Target"
	)
	target_data.defenses = ["ranged", "fire"]
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"type_defense",
		source,
		target,
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		&"fire",
		0
	)
	var execution := _execute_single_impact(
		battle_state,
		impact
	)
	var impact_result := execution.get_result(impact.impact_id)

	assert(
		impact_result.outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		impact_result.interaction_resolution.stage
		== InteractionResolution.Stage.DEFENSE_INTERACTION_TYPE
	)
	assert(not target.active_defenses.has("ranged"))
	assert(target.active_defenses.has("fire"))
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _test_source_defense_is_consumed() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("decay_source", "Decay Source"),
		1,
		0,
		2
	)
	var target_data := _make_unit_data(
		"decay_target",
		"Decay Target"
	)
	target_data.defenses = ["decay"]
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"source_defense",
		source,
		target,
		Impact.InteractionType.MAGIC,
		Impact.Operation.DAMAGE,
		&"decay",
		0
	)
	var execution := _execute_single_impact(
		battle_state,
		impact
	)
	var impact_result := execution.get_result(impact.impact_id)

	assert(
		impact_result.outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(
		impact_result.interaction_resolution.stage
		== InteractionResolution.Stage.DEFENSE_SOURCE_TYPE
	)
	assert(impact_result.consumed_defense == &"decay")
	assert(not target.active_defenses.has("decay"))
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _test_healing_defense_is_resolved_and_consumed() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("healing_source", "Healing Source"),
		1,
		0,
		2
	)
	var target_data := _make_unit_data(
		"healing_target",
		"Healing Target"
	)
	target_data.defenses = ["healing"]
	var target := battle_state.spawn_unit(
		target_data,
		1,
		1,
		2
	)
	target.take_damage(4)
	var hp_before := target.current_hp
	var impact := _make_impact(
		&"healing_defense",
		source,
		target,
		Impact.InteractionType.HEALING,
		Impact.Operation.HEAL,
		&"holy",
		0
	)
	var execution := _execute_single_impact(
		battle_state,
		impact
	)
	var impact_result := execution.get_result(impact.impact_id)

	assert(
		impact_result.outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(target.current_hp == hp_before)
	assert(not target.active_defenses.has("healing"))
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


# ============================================================
# БРОНЯ И БРОНЕБОЙНОСТЬ
# ============================================================

func _test_armor_scope_and_penetration() -> void:
	_assert_armor_is_used(Impact.InteractionType.MELEE)
	_assert_armor_is_used(Impact.InteractionType.RANGED)
	_assert_armor_is_used(Impact.InteractionType.MAGIC)
	_assert_armor_is_ignored(
		Impact.InteractionType.HEALING,
		Impact.Operation.HEAL
	)
	_assert_armor_is_ignored(
		Impact.InteractionType.SUMMON,
		Impact.Operation.SUMMON
	)
	_assert_armor_is_ignored(
		Impact.InteractionType.EFFECT,
		Impact.Operation.DAMAGE
	)
	_test_negative_penetration_increases_effective_armor()
	_test_positive_penetration_reduces_effective_armor()
	_test_out_of_range_penetration_is_rejected()


func _assert_armor_is_used(
	interaction_type : Impact.InteractionType
) -> void:
	var bundle := _make_resolution_bundle(
		interaction_type,
		Impact.Operation.DAMAGE,
		5,
		0
	)
	var resolution := bundle["resolution"] as InteractionResolution
	var battle_state := bundle["battle_state"] as BattleState

	assert(resolution.armor_was_checked)
	assert(
		resolution.outcome
		== InteractionResolution.Outcome.BLOCKED_ARMOR
	)
	assert(resolution.effective_armor == 5)
	assert(resolution.block_chance == 100)
	assert(battle_state.battle_rng.roll_history.size() == 1)

	battle_state.clear()


func _assert_armor_is_ignored(
	interaction_type : Impact.InteractionType,
	operation : Impact.Operation
) -> void:
	var armor_penetration := -5

	if interaction_type == Impact.InteractionType.EFFECT:
		armor_penetration = 0

	var bundle := _make_resolution_bundle(
		interaction_type,
		operation,
		5,
		armor_penetration
	)
	var resolution := bundle["resolution"] as InteractionResolution
	var battle_state := bundle["battle_state"] as BattleState

	assert(resolution.is_allowed())
	assert(not resolution.armor_was_checked)
	assert(resolution.armor_roll == null)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _test_negative_penetration_increases_effective_armor() -> void:
	var bundle := _make_resolution_bundle(
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		0,
		-5
	)
	var resolution := bundle["resolution"] as InteractionResolution
	var battle_state := bundle["battle_state"] as BattleState

	assert(resolution.effective_armor == 5)
	assert(resolution.block_chance == 100)
	assert(
		resolution.outcome
		== InteractionResolution.Outcome.BLOCKED_ARMOR
	)
	assert(resolution.armor_roll != null)
	assert(
		resolution.armor_roll.context["armor_penetration"]
		== -5
	)

	battle_state.clear()


func _test_positive_penetration_reduces_effective_armor() -> void:
	var bundle := _make_resolution_bundle(
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		5,
		5
	)
	var resolution := bundle["resolution"] as InteractionResolution
	var battle_state := bundle["battle_state"] as BattleState

	assert(resolution.is_allowed())
	assert(resolution.armor_was_checked)
	assert(resolution.effective_armor == 0)
	assert(resolution.block_chance == 0)
	assert(resolution.armor_roll == null)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _test_out_of_range_penetration_is_rejected() -> void:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("invalid_pen_source", "Invalid Pen Source"),
		1,
		0,
		2
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("invalid_pen_target", "Invalid Pen Target"),
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"invalid_penetration",
		source,
		target,
		Impact.InteractionType.RANGED,
		Impact.Operation.DAMAGE,
		&"physical",
		-6
	)
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var plan := ImpactPlan.create(
		impact.execution_id,
		ImpactPlan.Topology.TREE
	)
	assert(plan.add_root_impact(impact))
	var hp_before := target.current_hp
	var execution := ImpactExecutor.new().execute(
		plan,
		snapshot,
		battle_state
	)

	assert(
		execution.status
		== ImpactPlanExecutionResult.Status.VALIDATION_FAILED
	)
	assert(not execution.issues.is_empty())
	assert(target.current_hp == hp_before)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()


func _make_resolution_bundle(
	interaction_type : Impact.InteractionType,
	operation : Impact.Operation,
	target_armor : int,
	armor_penetration : int
) -> Dictionary:
	var battle_state := _make_battle_state()
	var source := battle_state.spawn_unit(
		_make_unit_data("armor_source", "Armor Source"),
		1,
		0,
		2
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("armor_target", "Armor Target", target_armor),
		2,
		6,
		2
	)
	var impact := _make_impact(
		&"armor_check",
		source,
		target,
		interaction_type,
		operation,
		&"physical",
		armor_penetration
	)
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var resolution := InteractionResolver.new().resolve(
		impact,
		snapshot.get_unit_snapshot(target),
		snapshot,
		battle_state.battle_rng
	)

	return {
		"battle_state": battle_state,
		"resolution": resolution
	}


# ============================================================
# ИСТОЧНИК ЛЕЧЕНИЯ В ОБЩЕМ ПУТИ АВТОРИНГА
# ============================================================

func _test_healing_source_reaches_impact_plan() -> void:
	var battle_state := _make_battle_state()
	var healing_ability := _make_healing_ability(&"holy")
	var source_data := _make_unit_data(
		"plan_healer",
		"Plan Healer"
	)
	source_data.active_abilities.append(healing_ability)
	var source := battle_state.spawn_unit(
		source_data,
		1,
		0,
		2
	)
	var target := battle_state.spawn_unit(
		_make_unit_data("plan_target", "Plan Target"),
		1,
		1,
		2
	)
	target.take_damage(2)

	var registry := AbilityAlgorithmRegistry.new()
	var schema := registry.validate_unit_ability(healing_ability)
	assert(schema.is_valid, schema.get_summary())
	assert(
		StringName(schema.resolved_parameters[
			AbilityAlgorithmRegistry.PARAM_KEYWORD
		]) == &"holy"
	)

	var targeting := TargetingService.new().resolve(
		battle_state,
		source,
		target,
		target.cell,
		healing_ability,
		schema.resolved_parameters
	)
	assert(targeting.is_valid, targeting.get_summary())

	var build_result := AbilityImpactPlanBuilder.new().build(
		&"healing_source_plan",
		source,
		source.active_abilities[0],
		targeting,
		schema.resolved_parameters
	)
	assert(build_result.is_valid, build_result.message)
	assert(build_result.plan.impacts.size() == 1)
	assert(build_result.plan.impacts[0].source_type == &"holy")
	assert(
		build_result.plan.impacts[0].interaction_type
		== Impact.InteractionType.HEALING
	)

	battle_state.clear()


# ============================================================
# FIXTURES
# ============================================================

func _make_battle_state() -> BattleState:
	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	return battle_state


func _make_unit_data(
	unit_id : String,
	unit_name : String,
	armor : int = 0
) -> UnitData:
	var unit_data := UnitData.new()
	unit_data.unit_id = unit_id
	unit_data.unit_name = unit_name
	unit_data.initiative = 10
	unit_data.max_hp = 10
	unit_data.armor = armor
	unit_data.movement = 3
	return unit_data


func _make_impact(
	impact_id : StringName,
	source : UnitRuntime,
	target : UnitRuntime,
	interaction_type : Impact.InteractionType,
	operation : Impact.Operation,
	source_type : StringName,
	armor_penetration : int
) -> Impact:
	var impact := Impact.create(
		impact_id,
		&"interaction_resolver_smoke",
		source,
		target,
		target.cell,
		operation,
		interaction_type,
		source_type,
		3,
		armor_penetration
	)
	impact.order_index = 0
	return impact


func _execute_single_impact(
	battle_state : BattleState,
	impact : Impact
) -> ImpactPlanExecutionResult:
	var snapshot := BattleStateSnapshot.capture(battle_state)
	var plan := ImpactPlan.create(
		impact.execution_id,
		ImpactPlan.Topology.TREE
	)
	assert(plan.add_root_impact(impact))
	return ImpactExecutor.new().execute(
		plan,
		snapshot,
		battle_state
	)


func _make_healing_ability(
	source_type : StringName
) -> UnitAbilityData:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Interaction smoke healing"
	mechanism.action_type = AbilityData.ActionType.HEAL
	mechanism.targeting_form = AbilityData.TargetingForm.RANGED
	mechanism.algorithm_id = "heal_target"
	mechanism.target_rule_id = "single_any_ally"
	mechanism.default_conditions = [
		"target_must_be_alive",
		"target_must_be_ally"
	]
	mechanism.default_parameters = {
		"keyword": String(source_type)
	}

	var unit_ability := UnitAbilityData.new()
	unit_ability.ability_name = "Interaction smoke healing"
	unit_ability.ability = mechanism
	unit_ability.parameters = {
		"heal": 3
	}
	return unit_ability
