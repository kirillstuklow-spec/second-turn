extends SceneTree


# ============================================================
# АВТОМАТИЧЕСКАЯ ПРОВЕРКА ARENA BUILDER
# ============================================================

const BUILDER_SCENE: PackedScene = preload(
	"res://Scense/Tools/ArenaBuilder/arena_builder.tscn"
)

const TEST_RESOURCE_PATH := (
	"res://Resources/Arenas/Arenas/Created/"
	+ "_arena_builder_smoke_test.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_remove_old_test_resource()

	var builder := BUILDER_SCENE.instantiate() as ArenaBuilder

	assert(builder != null)

	root.add_child(builder)
	await process_frame

	assert(builder._palette_visuals.size() > 0)
	assert(builder._grid_cells.size() == 35)
	assert(builder._cell_visuals.size() == 35)
	assert(builder._zones.size() == 35)

	builder.arena_id_edit.text = "arena_builder_smoke_test"
	builder.arena_name_edit.text = "Arena Builder Smoke Test"
	builder.description_edit.text = (
		"Автоматически созданная тестовая арена."
	)
	builder.cell_palette_option.select(0)
	builder._fill_all_cells()
	builder._apply_standard_deployment_zones()
	builder._load_background_texture("res://icon.svg")

	var arena_data := builder._build_arena_data()
	var report := ArenaValidator.validate(arena_data)

	assert(bool(report["is_valid"]))
	assert(arena_data.visual_placements.size() == 35)
	assert(arena_data.zone_placements.size() == 12)
	assert(arena_data.background_texture != null)
	assert(
		arena_data.get_zone_at(0, 1)
		== ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
	)
	assert(
		arena_data.get_zone_at(3, 2)
		== ArenaZonePlacementData.Zone.NONE
	)

	builder._save_arena_to_path(
		arena_data,
		TEST_RESOURCE_PATH
	)

	assert(FileAccess.file_exists(TEST_RESOURCE_PATH))

	var loaded_resource := ResourceLoader.load(
		TEST_RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	assert(loaded_resource is ArenaData)

	var loaded_arena := loaded_resource as ArenaData

	assert(loaded_arena.arena_id == "arena_builder_smoke_test")
	assert(loaded_arena.visual_placements.size() == 35)
	assert(loaded_arena.player_1_deployment_capacity == 6)
	assert(loaded_arena.player_2_deployment_capacity == 6)
	assert(loaded_arena.object_placements.is_empty())

	builder._load_arena_from_path(TEST_RESOURCE_PATH)

	assert(builder._current_resource_path == TEST_RESOURCE_PATH)
	assert(builder._cell_visuals[0] != null)
	assert(
		builder._count_zone(
			ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
		)
		== 6
	)

	builder.mode_option.select(ArenaBuilder.BuilderMode.OBJECTS)
	builder._set_mode(ArenaBuilder.BuilderMode.OBJECTS)
	assert(builder.object_panel.visible)
	assert(builder.object_refresh_button.disabled)

	print(
		"ArenaBuilderSmokeTest: PASS — create, paint, validate, "
		+ "save, load, background and object placeholder completed"
	)

	builder.queue_free()
	await process_frame

	_remove_old_test_resource()
	quit()


func _remove_old_test_resource() -> void:
	var absolute_path := ProjectSettings.globalize_path(
		TEST_RESOURCE_PATH
	)

	if FileAccess.file_exists(TEST_RESOURCE_PATH):
		DirAccess.remove_absolute(absolute_path)
