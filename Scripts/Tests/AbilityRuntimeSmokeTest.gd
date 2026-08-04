extends SceneTree


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var mechanism := AbilityData.new()
	mechanism.mechanism_name = "Runtime smoke mechanism"
	mechanism.algorithm_id = "deal_damage"
	mechanism.target_rule_id = "single_any_enemy"
	mechanism.default_conditions.append("target_must_be_alive")
	mechanism.default_conditions.append("target_must_be_enemy")

	var ability_data := UnitAbilityData.new()
	ability_data.ability_name = "Runtime smoke ability"
	ability_data.ability = mechanism
	ability_data.action_point_cost = 1
	ability_data.cooldown_rounds = 1
	ability_data.max_charges = 2
	ability_data.max_uses_per_battle = 2
	ability_data.max_uses_per_round = 1
	ability_data.max_uses_per_activation = 1
	ability_data.parameters = {
		"damage": 3,
		"armor_penetration": 0,
		"keyword": "physical"
	}

	var unit_data := UnitData.new()
	unit_data.unit_id = "ability_runtime_smoke_owner"
	unit_data.unit_name = "Ability Runtime Smoke Owner"
	unit_data.max_hp = 10
	unit_data.active_abilities.append(ability_data)

	var target_data := UnitData.new()
	target_data.unit_id = "ability_runtime_smoke_target"
	target_data.unit_name = "Ability Runtime Smoke Target"
	target_data.max_hp = 10

	var battle_state := BattleState.new()
	battle_state.generate_battlefield()

	var owner := battle_state.spawn_unit(
		unit_data,
		1,
		0,
		2
	)
	var second_owner := battle_state.spawn_unit(
		unit_data,
		1,
		0,
		1
	)
	var target := battle_state.spawn_unit(
		target_data,
		2,
		6,
		2
	)

	assert(owner != null)
	assert(second_owner != null)
	assert(target != null)
	assert(owner.active_abilities.size() == 1)
	assert(second_owner.active_abilities.size() == 1)

	var ability_runtime := owner.active_abilities[0]
	var second_ability_runtime := second_owner.active_abilities[0]

	assert(ability_runtime != null)
	assert(second_ability_runtime != null)
	assert(second_ability_runtime != ability_runtime)
	assert(ability_runtime.data == ability_data)
	assert(second_ability_runtime.data == ability_data)
	assert(ability_runtime.owner == owner)
	assert(second_ability_runtime.owner == second_owner)
	assert(ability_runtime.remaining_charges == 2)
	assert(second_ability_runtime.remaining_charges == 2)

	battle_state.set_active_unit(owner)
	owner.start_round(1)
	owner.start_activation(1, 0)

	var availability_service := AbilityAvailabilityService.new()
	var available_result := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	assert(available_result.is_available)

	var panel_scene := ResourceLoader.load(
		"res://Scense/UI/unit_info_panel.tscn"
	) as PackedScene
	var unit_info_panel := panel_scene.instantiate() as UnitInfoPanel

	assert(unit_info_panel != null)

	root.add_child(unit_info_panel)
	await process_frame

	unit_info_panel.show_unit(
		owner,
		true,
		[available_result]
	)

	assert(unit_info_panel.ability_grid.get_child_count() == 1)

	var ability_button := (
		unit_info_panel.ability_grid.get_child(0) as Button
	)
	var selected_abilities: Array[UnitAbilityRuntime] = []

	unit_info_panel.ability_selected.connect(
		func(selected_runtime : UnitAbilityRuntime) -> void:
			selected_abilities.append(selected_runtime)
	)

	assert(ability_button != null)
	assert(not ability_button.disabled)

	ability_button.pressed.emit()

	assert(selected_abilities.size() == 1)
	assert(selected_abilities[0] == ability_runtime)

	unit_info_panel.free()

	battle_state.set_pending_ability(ability_runtime)
	assert(battle_state.pending_ability == ability_runtime)

	var event_queue := EventQueue.new()
	var ability_pipeline := AbilityPipeline.new()
	var pipeline_runner := PipelineRunner.new()
	var command_dispatcher := CommandDispatcher.new()

	root.add_child(event_queue)
	root.add_child(ability_pipeline)
	root.add_child(pipeline_runner)
	root.add_child(command_dispatcher)

	ability_pipeline.configure(
		battle_state,
		availability_service
	)
	pipeline_runner.configure(
		ability_pipeline,
		null,
		null,
		event_queue
	)
	command_dispatcher.configure(
		battle_state,
		pipeline_runner
	)

	command_dispatcher.dispatch_command({
		"type": "use_ability",
		"source_unit": owner,
		"target_unit": target,
		"target_cell": target.cell,
		"ability_runtime": ability_runtime
	})

	assert(owner.action_points_remaining == 0)
	assert(target.current_hp == 7)
	assert(ability_runtime.last_execution_id != &"")

	assert(ability_runtime.remaining_charges == 1)
	assert(second_ability_runtime.remaining_charges == 2)
	assert(ability_runtime.uses_this_battle == 1)
	assert(second_ability_runtime.uses_this_battle == 0)
	assert(ability_runtime.uses_this_round == 1)
	assert(ability_runtime.uses_this_activation == 1)
	assert(ability_data.max_charges == 2)

	var blocked_after_use := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	assert(
		blocked_after_use.has_reason(
			AbilityAvailabilityReason.Code.COOLDOWN_ACTIVE
		)
	)
	assert(
		blocked_after_use.has_reason(
			AbilityAvailabilityReason.Code.ROUND_USE_LIMIT_REACHED
		)
	)
	assert(
		blocked_after_use.has_reason(
			AbilityAvailabilityReason.Code.ACTIVATION_USE_LIMIT_REACHED
		)
	)

	owner.finish_round(1)
	owner.start_round(2)
	owner.start_activation(2, 0)

	assert(ability_runtime.remaining_cooldown == 1)
	assert(
		availability_service.evaluate(
			battle_state,
			ability_runtime
		).has_reason(
			AbilityAvailabilityReason.Code.COOLDOWN_ACTIVE
		)
	)

	owner.finish_round(2)
	owner.start_round(3)
	owner.start_activation(3, 0)

	assert(ability_runtime.remaining_cooldown == 0)

	owner.action_points_remaining = 1

	var externally_blocked := availability_service.evaluate(
		battle_state,
		ability_runtime,
		[&"smoke_blocker"]
	)

	assert(
		externally_blocked.has_reason(
			AbilityAvailabilityReason.Code.EXTERNAL_BLOCKER
		)
	)

	var available_again := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	assert(available_again.is_available)

	command_dispatcher.dispatch_command({
		"type": "use_ability",
		"source_unit": owner,
		"target_unit": target,
		"target_cell": target.cell,
		"ability_runtime": ability_runtime
	})

	assert(owner.action_points_remaining == 0)
	assert(target.current_hp == 4)

	var exhausted_result := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	assert(
		exhausted_result.has_reason(
			AbilityAvailabilityReason.Code.CHARGES_DEPLETED
		)
	)
	assert(
		exhausted_result.has_reason(
			AbilityAvailabilityReason.Code.BATTLE_USE_LIMIT_REACHED
		)
	)

	print(
		"AbilityRuntimeSmokeTest: PASS — isolated runtime ownership, UI/command "
		+ "payload contract, availability, charges, cooldown and limits"
	)

	battle_state.clear()
	command_dispatcher.free()
	pipeline_runner.free()
	ability_pipeline.free()
	event_queue.free()
	call_deferred("_quit_after_cleanup")


func _quit_after_cleanup() -> void:
	quit()
