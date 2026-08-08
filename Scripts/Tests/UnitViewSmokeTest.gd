extends SceneTree


# ============================================================
# АВТОМАТИЧЕСКАЯ ПРОВЕРКА UNIT VIEW В НАСТОЯЩЕМ БОЮ
# ============================================================

func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var battle_scene_resource := ResourceLoader.load(
		"res://Scense/Battle/battle_scene.tscn"
	) as PackedScene

	assert(battle_scene_resource != null)

	var battle_scene := battle_scene_resource.instantiate()

	assert(battle_scene != null)

	root.add_child(battle_scene)
	await process_frame

	var battle_engine := battle_scene.get_node(
		"BattleEngine"
	) as BattleEngine
	var battlefield_view := battle_scene.get_node(
		"Battlefield"
	) as BattlefieldView

	assert(battle_engine != null)
	assert(battle_engine.battle_state != null)
	assert(battlefield_view != null)
	assert(battle_engine.battle_state.units.size() == 2)
	assert(battlefield_view._unit_views_by_id.size() == 2)

	var test_unit := battle_engine.battle_state.units[0]
	var test_unit_id := test_unit.get_instance_id()
	var test_view := (
		battlefield_view._unit_views_by_id[test_unit_id]
		as UnitView
	)

	assert(test_view != null)
	assert(test_view.fallback_panel.visible)

	var target_cell := battle_engine.battle_state.get_cell_at(
		1,
		1
	)

	assert(
		battle_engine.battle_state.move_unit(
			test_unit,
			target_cell
		)
	)

	battlefield_view.draw_battlefield(
		battle_engine.battle_state
	)

	await create_timer(0.25).timeout

	var expected_position := Vector2(
		1 * BattlefieldView.CELL_SIZE.x
		+ BattlefieldView.CELL_SIZE.x * 0.5,
		1 * BattlefieldView.CELL_SIZE.y
		+ BattlefieldView.CELL_SIZE.y * 0.5
	)

	assert(test_view.position.is_equal_approx(expected_position))

	test_unit.take_damage(999)
	battle_engine.battle_state.cleanup_dead_units()
	battlefield_view.draw_battlefield(
		battle_engine.battle_state
	)

	assert(
		not battlefield_view._unit_views_by_id.has(
			test_unit_id
		)
	)

	print(
		"UnitViewSmokeTest: PASS — spawn, fallback, "
		+ "movement and death cleanup completed"
	)

	battle_scene.free()

	test_view = null
	test_unit = null
	target_cell = null
	battlefield_view = null
	battle_engine = null
	battle_scene = null
	battle_scene_resource = null

	call_deferred("_quit_after_cleanup")


func _quit_after_cleanup() -> void:
	quit()
