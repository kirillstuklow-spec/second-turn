extends SceneTree


# ============================================================
# АВТОМАТИЧЕСКАЯ ПРОВЕРКА ARENA DATA И RUNTIME
# ============================================================

const TEST_ARENA_PATH := (
	"res://Resources/Arenas/Arenas/TestArena.tres"
)

const BATTLE_SCENE_PATH := (
	"res://Scense/Battle/battle_scene.tscn"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var arena_data := ResourceLoader.load(
		TEST_ARENA_PATH
	) as ArenaData

	assert(arena_data != null)

	var validation := ArenaValidator.validate(
		arena_data
	)

	assert(bool(validation["is_valid"]))
	assert(arena_data.width == 7)
	assert(arena_data.height == 5)
	assert(arena_data.get_cell_visual_at(0, 0) != null)
	assert(
		arena_data.get_cell_visual_at(3, 2).cell_visual_id
		== "test_accent"
	)
	assert(
		arena_data.get_zone_at(0, 2)
		== ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
	)
	assert(
		arena_data.get_zone_at(1, 2)
		== ArenaZonePlacementData.Zone.NEUTRAL
	)

	var test_state := BattleState.new()
	test_state.generate_battlefield(arena_data)

	assert(test_state.field_width == 7)
	assert(test_state.field_height == 5)
	assert(test_state.cells.size() == 35)
	assert(test_state.get_cell_at(3, 2).visual_data != null)
	assert(
		test_state.get_cell_at(6, 2).zone
		== CellRuntime.CellZone.PLAYER_2_DEPLOYMENT
	)

	test_state.clear()
	test_state.generate_battlefield()

	assert(test_state.cells.size() == 35)
	assert(test_state.get_cell_at(0, 2).visual_data == null)
	assert(
		test_state.get_cell_at(0, 2).zone
		== CellRuntime.CellZone.PLAYER_1_DEPLOYMENT
	)

	var battle_scene_resource := ResourceLoader.load(
		BATTLE_SCENE_PATH
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
	assert(battle_engine.arena_data != null)
	assert(battle_engine.battle_state != null)
	assert(battlefield_view != null)
	assert(battle_engine.battle_state.cells.size() == 35)
	assert(battlefield_view.cells_root.get_child_count() == 35)
	assert(battlefield_view._unit_views_by_id.size() == 4)

	var first_cell_view := (
		battlefield_view.cells_root.get_child(0)
		as Control
	)

	assert(first_cell_view != null)
	assert(_contains_texture_rect(first_cell_view))

	var test_unit := battle_engine.battle_state.units[0]
	var target_cell := battle_engine.battle_state.get_cell_at(
		1,
		2
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

	assert(
		test_unit.cell == target_cell
	)

	print(
		"ArenaRuntimeSmokeTest: PASS — load, validate, "
		+ "build field, draw textures and preserve battle movement"
	)

	battle_scene.free()
	test_state.clear()

	call_deferred("_quit_after_cleanup")


# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================

func _contains_texture_rect(
	parent: Node
) -> bool:
	for child in parent.get_children():
		if child is TextureRect:
			return true

		if _contains_texture_rect(child):
			return true

	return false


func _quit_after_cleanup() -> void:
	quit()
