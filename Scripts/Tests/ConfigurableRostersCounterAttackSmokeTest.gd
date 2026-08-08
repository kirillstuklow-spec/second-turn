extends SceneTree


const TEST_SEED : int = 20260807

const TEST_ARENA_PATH : String = (
	"res://Resources/Arenas/Arenas/TestArena.tres"
)
const COUNTER_ATTACK_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/CounterAttack.tres"
)
const MELEE_STRIKE_PATH : String = (
	"res://Resources/Abilities/UnitAbilityData/MeleeStrike.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_test_roster_validation_and_linear_deployment()
	_test_counter_attack_schema_and_half_actual_damage()
	_test_counter_attack_uses_normal_defense_and_armor()
	_test_counter_attack_does_not_chain_or_survive_lethal_damage()

	print(
		"ConfigurableRostersCounterAttackSmokeTest: PASS — inspector "
		+ "rosters, 6+6 linear deployment, triggered ability source, "
		+ "ceil(actual HP lost / 2), normal MELEE + PHYSICAL defenses "
		+ "and armor, no counter-chain and no post-mortem counter"
	)

	quit()


# ============================================================
# СОСТАВЫ И АВТОСПАВН
# ============================================================

func _test_roster_validation_and_linear_deployment() -> void:
	var arena := load(TEST_ARENA_PATH) as ArenaData
	assert(arena != null)
	assert(ArenaValidator.validate(arena)["is_valid"])
	assert(arena.player_1_deployment_capacity == 6)
	assert(arena.player_2_deployment_capacity == 6)

	var repeated_data := _make_unit_data(
		"repeated_spawn",
		"Repeated Spawn",
		10
	)
	var player_1_units : Array[UnitData] = []
	var player_2_units : Array[UnitData] = []

	for unit_index in range(6):
		player_1_units.append(repeated_data)
		player_2_units.append(repeated_data)

	var roster_validation := BattleRosterValidator.validate(
		player_1_units,
		player_2_units,
		arena
	)
	assert(roster_validation["is_valid"])

	var battle_state := BattleState.new()
	battle_state.generate_battlefield(arena)
	var initializer := BattleInitializer.new()
	root.add_child(initializer)
	assert(initializer.initialize_test_battle(
		battle_state,
		player_1_units,
		player_2_units
	))
	assert(battle_state.units.size() == 12)

	var expected_player_1 : Array[Vector2i] = [
		Vector2i(0, 1),
		Vector2i(1, 1),
		Vector2i(0, 2),
		Vector2i(1, 2),
		Vector2i(0, 3),
		Vector2i(1, 3)
	]
	var expected_player_2 : Array[Vector2i] = [
		Vector2i(5, 1),
		Vector2i(6, 1),
		Vector2i(5, 2),
		Vector2i(6, 2),
		Vector2i(5, 3),
		Vector2i(6, 3)
	]

	for unit_index in range(6):
		_assert_unit_spawn(
			battle_state.units[unit_index],
			1,
			expected_player_1[unit_index]
		)
		_assert_unit_spawn(
			battle_state.units[unit_index + 6],
			2,
			expected_player_2[unit_index]
		)
		assert(
			battle_state.units[unit_index]
			!= battle_state.units[unit_index + 6]
		)

	assert(battle_state.units[0].data == repeated_data)
	assert(battle_state.units[1].data == repeated_data)
	assert(battle_state.units[0] != battle_state.units[1])

	battle_state.clear()
	initializer.free()

	var oversized : Array[UnitData] = []

	for unit_index in range(7):
		oversized.append(repeated_data)

	assert(not BattleRosterValidator.validate(
		oversized,
		player_2_units,
		arena
	)["is_valid"])

	var empty_state := BattleState.new()
	empty_state.generate_battlefield(arena)
	initializer = BattleInitializer.new()
	root.add_child(initializer)
	assert(not initializer.initialize_test_battle(
		empty_state,
		oversized,
		player_2_units
	))
	assert(empty_state.units.is_empty())
	empty_state.clear()
	initializer.free()


func _assert_unit_spawn(
	unit : UnitRuntime,
	team_id : int,
	expected_cell : Vector2i
) -> void:
	assert(unit != null)
	assert(unit.team_id == team_id)
	assert(unit.cell != null)
	assert(unit.cell.x == expected_cell.x)
	assert(unit.cell.y == expected_cell.y)


# ============================================================
# КОНТР-УДАР КАК АВТОМАТИЧЕСКАЯ СПОСОБНОСТЬ
# ============================================================

func _test_counter_attack_schema_and_half_actual_damage() -> void:
	var counter_attack := _load_counter_attack()
	var schema := AbilityAlgorithmRegistry.new().validate_unit_ability(
		counter_attack
	)
	assert(schema.is_valid, schema.get_summary())
	assert(
		counter_attack.ability.activation_mode
		== AbilityData.ActivationMode.TRIGGERED
	)
	assert(counter_attack.action_point_cost == 0)
	assert(counter_attack.triggers.size() == 1)
	assert(
		counter_attack.triggers[0].interaction_filter
		== AbilityTriggerData.InteractionFilter.MELEE
	)
	assert(not counter_attack.triggers[0].accept_reaction_events)

	var node := counter_attack.impact_plan_data.nodes[0]
	assert(node.target_reference == ImpactNodeData.TargetReference.EVENT_SOURCE)
	assert(node.interaction_type == Impact.InteractionType.MELEE)
	assert(node.source_type == "physical")
	assert(
		node.magnitude_source
		== ImpactNodeData.MagnitudeSource.EVENT_APPLIED_AMOUNT
	)
	assert(node.magnitude_numerator == 1)
	assert(node.magnitude_denominator == 2)
	assert(node.magnitude_rounding == ImpactNodeData.MagnitudeRounding.CEIL)

	var bundle := _make_counter_battle(20, true)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var attacker := bundle["attacker"] as UnitRuntime
	var defender := bundle["defender"] as UnitRuntime
	var hp_before := attacker.current_hp
	var execution := pipeline.execute_ability(
		attacker,
		defender,
		attacker.active_abilities[0],
		defender.cell
	)

	assert(execution.was_committed(), execution.message)
	assert(defender.current_hp == 15)
	assert(attacker.current_hp == hp_before - 3)
	assert(
		execution.impact_execution_result.reaction_execution_results.size()
		== 1
	)

	var counter_result : ImpactResult = (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)
	assert(counter_result.magnitude_requested == 3)
	assert(counter_result.magnitude_applied == 3)
	assert(counter_result.impact.source_unit == defender)
	assert(counter_result.impact.target_unit == attacker)
	assert(counter_result.impact.source_ability_data == counter_attack)
	assert(counter_result.impact.origin_effect_runtime_id == &"")
	assert(counter_result.impact.reaction_depth == 1)
	assert(counter_result.interaction_resolution.armor_was_checked)

	var combat_event_log := bundle["combat_event_log"] as CombatEventLog
	assert(combat_event_log.history.size() == 2)
	assert(combat_event_log.history[1].source_ability_data == counter_attack)
	assert(combat_event_log.history[1].interaction_type == Impact.InteractionType.MELEE)
	assert(combat_event_log.history[1].source_type == &"physical")

	_free_counter_bundle(bundle)


func _test_counter_attack_uses_normal_defense_and_armor() -> void:
	var bundle := _make_counter_battle(20, false)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var attacker := bundle["attacker"] as UnitRuntime
	var defender := bundle["defender"] as UnitRuntime
	attacker.active_defenses.append("physical")
	var hp_before := attacker.current_hp
	var execution := pipeline.execute_ability(
		attacker,
		defender,
		attacker.active_abilities[0],
		defender.cell
	)
	var blocked_by_defense : ImpactResult = (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)

	assert(defender.current_hp == 15)
	assert(attacker.current_hp == hp_before)
	assert(not attacker.active_defenses.has("physical"))
	assert(
		blocked_by_defense.outcome
		== ImpactResult.Outcome.BLOCKED_DEFENSE
	)
	assert(blocked_by_defense.consumed_defense == &"physical")

	_free_counter_bundle(bundle)

	bundle = _make_counter_battle(20, false)
	pipeline = bundle["pipeline"] as AbilityPipeline
	attacker = bundle["attacker"] as UnitRuntime
	defender = bundle["defender"] as UnitRuntime
	attacker.armor = 5
	hp_before = attacker.current_hp
	execution = pipeline.execute_ability(
		attacker,
		defender,
		attacker.active_abilities[0],
		defender.cell
	)
	var blocked_by_armor : ImpactResult = (
		execution.impact_execution_result
		.reaction_execution_results[0]
		.impact_results[0]
	)

	assert(attacker.current_hp == hp_before)
	assert(blocked_by_armor.outcome == ImpactResult.Outcome.BLOCKED_ARMOR)
	assert(blocked_by_armor.interaction_resolution.armor_was_checked)
	assert(blocked_by_armor.effective_armor == 5)
	assert(blocked_by_armor.block_chance == 100)

	_free_counter_bundle(bundle)


func _test_counter_attack_does_not_chain_or_survive_lethal_damage() -> void:
	# Оба юнита несут Контр-удар. Ответ глубины 1 является обычным уроном,
	# но сам триггер Контр-удара такие реакционные события не принимает.
	var bundle := _make_counter_battle(20, true)
	var pipeline := bundle["pipeline"] as AbilityPipeline
	var attacker := bundle["attacker"] as UnitRuntime
	var defender := bundle["defender"] as UnitRuntime
	var execution := pipeline.execute_ability(
		attacker,
		defender,
		attacker.active_abilities[0],
		defender.cell
	)
	assert(execution.was_committed())
	assert(
		execution.impact_execution_result.reaction_execution_results.size()
		== 1
	)

	_free_counter_bundle(bundle)

	# Смертельный удар меняет is_alive до сбора реакций. Посмертный ответ
	# остаётся отдельной механикой Кающегося и не предоставляется Контр-удару.
	bundle = _make_counter_battle(5, false)
	pipeline = bundle["pipeline"] as AbilityPipeline
	attacker = bundle["attacker"] as UnitRuntime
	defender = bundle["defender"] as UnitRuntime
	var attacker_hp_before := attacker.current_hp
	execution = pipeline.execute_ability(
		attacker,
		defender,
		attacker.active_abilities[0],
		defender.cell
	)
	assert(execution.was_committed())
	assert(not defender.is_alive)
	assert(defender.cell == null)
	assert(attacker.current_hp == attacker_hp_before)
	assert(execution.impact_execution_result.reaction_execution_results.is_empty())

	_free_counter_bundle(bundle)


# ============================================================
# ТЕСТОВЫЙ БОЙ И ЗАВИСИМОСТИ
# ============================================================

func _make_counter_battle(
	defender_max_hp : int,
	attacker_also_has_counter : bool
) -> Dictionary:
	var melee_strike := load(MELEE_STRIKE_PATH) as UnitAbilityData
	var counter_attack := _load_counter_attack()
	assert(melee_strike != null)

	var attacker_data := _make_unit_data("attacker", "Attacker", 20)
	attacker_data.active_abilities.append(melee_strike)

	if attacker_also_has_counter:
		attacker_data.passive_abilities.append(counter_attack)

	var defender_data := _make_unit_data(
		"counter_owner",
		"Counter Owner",
		defender_max_hp
	)
	defender_data.passive_abilities.append(counter_attack)

	var battle_state := BattleState.new()
	battle_state.configure_battle_rng(TEST_SEED)
	battle_state.generate_battlefield()
	var attacker := battle_state.spawn_unit(attacker_data, 1, 0, 2)
	var defender := battle_state.spawn_unit(defender_data, 2, 1, 2)
	assert(attacker != null)
	assert(defender != null)
	battle_state.set_active_unit(attacker)
	attacker.start_round(1)
	attacker.start_activation(1, 0)
	defender.start_round(1)

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
		"attacker": attacker,
		"defender": defender,
		"pipeline": pipeline,
		"combat_event_log": combat_event_log
	}


func _make_unit_data(
	unit_id : String,
	unit_name : String,
	max_hp : int
) -> UnitData:
	var data := UnitData.new()
	data.unit_id = unit_id
	data.unit_name = unit_name
	data.max_hp = max_hp
	data.armor = 0
	data.movement = 2
	data.initiative = 10
	return data


func _load_counter_attack() -> UnitAbilityData:
	var counter_attack := load(COUNTER_ATTACK_PATH) as UnitAbilityData
	assert(counter_attack != null)
	return counter_attack


func _free_counter_bundle(bundle : Dictionary) -> void:
	var battle_state := bundle.get("battle_state", null) as BattleState
	var pipeline := bundle.get("pipeline", null) as AbilityPipeline

	if battle_state != null:
		battle_state.clear()

	if pipeline != null:
		pipeline.free()
