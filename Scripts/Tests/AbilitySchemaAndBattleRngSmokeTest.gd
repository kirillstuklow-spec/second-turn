extends SceneTree


const TEST_SEED : int = 20260804


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var registry := AbilityAlgorithmRegistry.new()

	_test_registry_catalog(registry)
	_test_defaults_and_overrides(registry)
	_test_strict_schema_failures(registry)
	_test_existing_ability_resources(registry)
	_test_rng_reproducibility()
	_test_invalid_schema_does_not_commit(registry)
	_test_invalid_targets_do_not_commit(registry)
	_test_pipelines_share_battle_rng(registry)

	print(
		"AbilitySchemaAndBattleRngSmokeTest: PASS — strict algorithms, "
		+ "defaults + overrides, pre-commit rejection and one reproducible RNG"
	)

	quit()


# ============================================================
# РЕЕСТР И СХЕМЫ
# ============================================================

func _test_registry_catalog(
	registry : AbilityAlgorithmRegistry
) -> void:
	assert(registry.has_algorithm(
		AbilityAlgorithmRegistry.ALGORITHM_DEAL_DAMAGE
	))
	assert(registry.has_algorithm(
		AbilityAlgorithmRegistry.ALGORITHM_HEAL_TARGET
	))
	assert(registry.has_algorithm(
		AbilityAlgorithmRegistry.ALGORITHM_EXECUTE_IMPACT_PLAN
	))
	assert(registry.get_definitions().size() == 3)

	var damage_definition := registry.get_definition(
		AbilityAlgorithmRegistry.ALGORITHM_DEAL_DAMAGE
	)

	assert(damage_definition != null)
	assert(damage_definition.parameter_specs.size() == 4)
	assert(
		damage_definition.get_parameter_spec(
			AbilityAlgorithmRegistry.PARAM_DAMAGE
		) != null
	)


func _test_defaults_and_overrides(
	registry : AbilityAlgorithmRegistry
) -> void:
	var unit_ability := _make_damage_ability()
	var original_defaults := (
		unit_ability.ability.default_parameters.duplicate(true)
	)
	var original_overrides := unit_ability.parameters.duplicate(true)
	var validation := registry.validate_unit_ability(unit_ability)

	assert(validation.is_valid, validation.get_summary())
	assert(
		validation.resolved_parameters[
			AbilityAlgorithmRegistry.PARAM_DAMAGE
		] == 3
	)
	assert(
		validation.resolved_parameters[
			AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
		] == -2
	)
	assert(
		validation.resolved_parameters[
			AbilityAlgorithmRegistry.PARAM_KEYWORD
		] == "physical"
	)
	assert(
		unit_ability.ability.default_parameters
		== original_defaults
	)
	assert(unit_ability.parameters == original_overrides)

	unit_ability.parameters[
		AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
	] = 4
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.is_valid, validation.get_summary())
	assert(
		validation.resolved_parameters[
			AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
		] == 4
	)

	unit_ability.parameters[
		AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
	] = -5
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.is_valid, validation.get_summary())


func _test_strict_schema_failures(
	registry : AbilityAlgorithmRegistry
) -> void:
	var unit_ability := _make_damage_ability()
	unit_ability.parameters = {
		"damage": 3,
		"armor_penetration ": 0,
		"keyword": "physical"
	}

	var validation := registry.validate_unit_ability(unit_ability)

	assert(not validation.is_valid)
	assert(validation.has_issue(
		AbilitySchemaIssue.Code.PARAMETER_KEY_HAS_SURROUNDING_WHITESPACE
	))

	unit_ability = _make_damage_ability()
	unit_ability.parameters["damage"] = 3.0
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.PARAMETER_TYPE_MISMATCH
	))

	unit_ability = _make_damage_ability()
	unit_ability.parameters["unknown_parameter"] = 1
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.UNKNOWN_PARAMETER
	))

	unit_ability = _make_damage_ability()
	unit_ability.parameters.erase("damage")
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.REQUIRED_PARAMETER_MISSING
	))

	unit_ability = _make_damage_ability()
	unit_ability.parameters[
		AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
	] = -6
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.PARAMETER_BELOW_MINIMUM
	))

	unit_ability = _make_damage_ability()
	unit_ability.ability.algorithm_id = "unknown_algorithm"
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.UNKNOWN_ALGORITHM
	))

	unit_ability = _make_damage_ability()
	unit_ability.ability.target_rule_id = "single_any_ally"
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.TARGET_RULE_NOT_ALLOWED
	))

	unit_ability = _make_damage_ability()
	unit_ability.ability.default_conditions.append(
		"unknown_condition"
	)
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.UNKNOWN_CONDITION
	))

	unit_ability = _make_damage_ability()
	unit_ability.conditions.append("target_must_be_enemy")
	validation = registry.validate_unit_ability(unit_ability)

	assert(validation.has_issue(
		AbilitySchemaIssue.Code.DUPLICATE_CONDITION
	))


func _test_existing_ability_resources(
	registry : AbilityAlgorithmRegistry
) -> void:
	var directory := DirAccess.open(
		"res://Resources/Abilities/UnitAbilityData"
	)

	assert(directory != null)

	for file_name in directory.get_files():
		if file_name.get_extension().to_lower() != "tres":
			continue

		var resource_path := (
			"res://Resources/Abilities/UnitAbilityData/"
			+ file_name
		)
		var unit_ability := ResourceLoader.load(
			resource_path,
			"",
			ResourceLoader.CACHE_MODE_REPLACE
		) as UnitAbilityData

		assert(unit_ability != null, resource_path)

		var validation := registry.validate_unit_ability(
			unit_ability
		)

		assert(
			validation.is_valid,
			resource_path + "\n" + validation.get_summary()
		)


# ============================================================
# ВОСПРОИЗВОДИМЫЙ RNG
# ============================================================

func _test_rng_reproducibility() -> void:
	var first_rng := BattleRng.new(TEST_SEED)
	var second_rng := BattleRng.new(TEST_SEED)

	for roll_index in range(8):
		var first_roll := first_rng.roll_int(
			&"reproducibility_check",
			-5,
			100,
			{
				"roll_index": roll_index
			}
		)
		var second_roll := second_rng.roll_int(
			&"reproducibility_check",
			-5,
			100,
			{
				"roll_index": roll_index
			}
		)

		assert(first_roll != null)
		assert(second_roll != null)
		assert(first_roll.value == second_roll.value)
		assert(first_roll.state_before == second_roll.state_before)
		assert(first_roll.state_after == second_roll.state_after)

	assert(first_rng.current_state == second_rng.current_state)
	assert(first_rng.roll_history.size() == 8)

	var saved_state := first_rng.current_state
	var expected_roll := first_rng.roll_int(
		&"state_restore_check",
		1,
		1000
	)
	var replay_rng := BattleRng.new(TEST_SEED)
	replay_rng.restore_state(saved_state)

	var replayed_roll := replay_rng.roll_int(
		&"state_restore_check",
		1,
		1000
	)

	assert(expected_roll.value == replayed_roll.value)
	assert(expected_roll.state_after == replayed_roll.state_after)


# ============================================================
# COMMIT-ГРАНИЦА И ОБЩИЙ ПОТОК RNG
# ============================================================

func _test_invalid_schema_does_not_commit(
	registry : AbilityAlgorithmRegistry
) -> void:
	var invalid_ability := _make_damage_ability()
	invalid_ability.parameters = {
		"damage": 3,
		"armor_penetration ": 0,
		"keyword": "physical"
	}

	var owner_data := _make_unit_data(
		"invalid_schema_owner",
		"Invalid Schema Owner",
		100,
		0
	)
	owner_data.active_abilities.append(invalid_ability)

	var target_data := _make_unit_data(
		"invalid_schema_target",
		"Invalid Schema Target",
		0,
		0
	)

	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()

	var owner := battle_state.spawn_unit(owner_data, 1, 0, 2)
	var target := battle_state.spawn_unit(target_data, 2, 6, 2)

	assert(owner != null)
	assert(target != null)

	battle_state.set_active_unit(owner)
	owner.start_round(1)
	owner.start_activation(1, 0)

	var ability_runtime : UnitAbilityRuntime = owner.active_abilities[0]
	var availability_service := AbilityAvailabilityService.new(
		registry
	)
	var availability := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	assert(not availability.is_available)
	assert(availability.has_reason(
		AbilityAvailabilityReason.Code.ABILITY_SCHEMA_INVALID
	))

	var ability_pipeline := AbilityPipeline.new()
	root.add_child(ability_pipeline)
	ability_pipeline.configure(
		battle_state,
		availability_service,
		registry
	)

	var owner_ap_before := owner.action_points_remaining
	var target_hp_before := target.current_hp

	ability_pipeline.execute_ability(
		owner,
		target,
		ability_runtime,
		target.cell
	)

	assert(owner.action_points_remaining == owner_ap_before)
	assert(ability_runtime.uses_this_battle == 0)
	assert(target.current_hp == target_hp_before)
	assert(battle_state.battle_rng.roll_history.is_empty())

	battle_state.clear()
	ability_pipeline.free()


func _test_invalid_targets_do_not_commit(
	registry : AbilityAlgorithmRegistry
) -> void:
	var ranged_attack := _make_damage_ability()
	var healing := _make_healing_ability()
	var melee_attack := _make_damage_ability(
		"single_adjacent_enemy"
	)

	var invalid_target_abilities : Array[UnitAbilityData] = [
		ranged_attack,
		healing,
		melee_attack
	]

	for unit_ability in invalid_target_abilities:
		unit_ability.max_charges = 1
		unit_ability.cooldown_rounds = 1

	var owner_data := _make_unit_data(
		"invalid_target_owner",
		"Invalid Target Owner",
		100,
		0
	)
	owner_data.active_abilities.append(ranged_attack)
	owner_data.active_abilities.append(healing)
	owner_data.active_abilities.append(melee_attack)

	var ally_data := _make_unit_data(
		"invalid_target_ally",
		"Invalid Target Ally",
		0,
		0
	)
	var enemy_data := _make_unit_data(
		"invalid_target_enemy",
		"Invalid Target Enemy",
		0,
		0
	)

	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()

	var owner := battle_state.spawn_unit(owner_data, 1, 0, 2)
	var ally := battle_state.spawn_unit(ally_data, 1, 1, 2)
	var distant_enemy := battle_state.spawn_unit(
		enemy_data,
		2,
		6,
		2
	)

	assert(owner != null)
	assert(ally != null)
	assert(distant_enemy != null)

	battle_state.set_active_unit(owner)
	owner.start_round(1)
	owner.start_activation(1, 0)

	var availability_service := AbilityAvailabilityService.new(
		registry
	)
	var ability_pipeline := AbilityPipeline.new()
	root.add_child(ability_pipeline)
	ability_pipeline.configure(
		battle_state,
		availability_service,
		registry
	)

	var owner_ap_before := owner.action_points_remaining
	var ally_hp_before := ally.current_hp
	var enemy_hp_before := distant_enemy.current_hp

	ability_pipeline.execute_ability(
		owner,
		ally,
		owner.active_abilities[0],
		ally.cell
	)
	ability_pipeline.execute_ability(
		owner,
		distant_enemy,
		owner.active_abilities[1],
		distant_enemy.cell
	)
	ability_pipeline.execute_ability(
		owner,
		distant_enemy,
		owner.active_abilities[2],
		distant_enemy.cell
	)

	assert(owner.action_points_remaining == owner_ap_before)
	assert(ally.current_hp == ally_hp_before)
	assert(distant_enemy.current_hp == enemy_hp_before)
	assert(battle_state.battle_rng.roll_history.is_empty())

	for ability_runtime in owner.active_abilities:
		assert(ability_runtime.uses_this_battle == 0)
		assert(ability_runtime.remaining_cooldown == 0)
		assert(ability_runtime.remaining_charges == 1)

	battle_state.clear()
	ability_pipeline.free()


func _test_pipelines_share_battle_rng(
	registry : AbilityAlgorithmRegistry
) -> void:
	var valid_ability := _make_damage_ability()
	valid_ability.ability.default_parameters[
		AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
	] = 0

	var owner_data := _make_unit_data(
		"shared_rng_owner",
		"Shared RNG Owner",
		100,
		0
	)
	owner_data.active_abilities.append(valid_ability)

	var target_data := _make_unit_data(
		"shared_rng_target",
		"Shared RNG Target",
		0,
		5
	)

	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()

	var owner := battle_state.spawn_unit(owner_data, 1, 0, 2)
	var target := battle_state.spawn_unit(target_data, 2, 6, 2)

	assert(owner != null)
	assert(target != null)

	var event_queue := EventQueue.new()
	var turn_pipeline := TurnPipeline.new()
	var ability_pipeline := AbilityPipeline.new()
	var availability_service := AbilityAvailabilityService.new(
		registry
	)

	root.add_child(event_queue)
	root.add_child(turn_pipeline)
	root.add_child(ability_pipeline)

	turn_pipeline.configure(battle_state, event_queue)
	ability_pipeline.configure(
		battle_state,
		availability_service,
		registry
	)

	turn_pipeline.start_battle_flow()

	assert(battle_state.active_unit == owner)
	assert(battle_state.battle_rng.roll_history.size() == 2)
	assert(
		battle_state.battle_rng.roll_history[0].purpose
		== TurnPipeline.RNG_PURPOSE_INITIATIVE_MODIFIER
	)
	assert(
		battle_state.battle_rng.roll_history[1].purpose
		== TurnPipeline.RNG_PURPOSE_INITIATIVE_MODIFIER
	)

	var ability_runtime : UnitAbilityRuntime = owner.active_abilities[0]
	var target_hp_before := target.current_hp

	ability_pipeline.execute_ability(
		owner,
		target,
		ability_runtime,
		target.cell
	)

	assert(battle_state.battle_rng.roll_history.size() == 3)
	assert(
		battle_state.battle_rng.roll_history[2].purpose
		== AbilityPipeline.RNG_PURPOSE_ARMOR_BLOCK
	)
	assert(target.current_hp == target_hp_before)
	assert(owner.action_points_remaining == 0)
	assert(ability_runtime.uses_this_battle == 1)

	battle_state.clear()
	ability_pipeline.free()
	turn_pipeline.free()
	event_queue.free()


# ============================================================
# FIXTURES
# ============================================================

func _make_damage_ability(
	target_rule_id : String = "single_any_enemy"
) -> UnitAbilityData:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Schema smoke damage"
	mechanism.action_type = AbilityData.ActionType.ATTACK
	mechanism.algorithm_id = "deal_damage"
	mechanism.target_rule_id = target_rule_id
	mechanism.default_conditions = [
		"target_must_be_alive",
		"target_must_be_enemy"
	]
	mechanism.default_parameters = {
		"armor_penetration": -2,
		"keyword": "physical"
	}

	var unit_ability := UnitAbilityData.new()
	unit_ability.ability_name = "Schema smoke shot"
	unit_ability.ability = mechanism
	unit_ability.parameters = {
		"damage": 3
	}

	return unit_ability


func _make_healing_ability() -> UnitAbilityData:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Schema smoke healing"
	mechanism.action_type = AbilityData.ActionType.HEAL
	mechanism.algorithm_id = "heal_target"
	mechanism.target_rule_id = "single_any_ally"
	mechanism.default_conditions = [
		"target_must_be_alive",
		"target_must_be_ally"
	]

	var unit_ability := UnitAbilityData.new()
	unit_ability.ability_name = "Schema smoke healing"
	unit_ability.ability = mechanism
	unit_ability.parameters = {
		"heal": 3
	}

	return unit_ability


func _make_unit_data(
	unit_id : String,
	unit_name : String,
	initiative : int,
	armor : int
) -> UnitData:
	var unit_data := UnitData.new()
	unit_data.unit_id = unit_id
	unit_data.unit_name = unit_name
	unit_data.initiative = initiative
	unit_data.max_hp = 10
	unit_data.armor = armor
	return unit_data
