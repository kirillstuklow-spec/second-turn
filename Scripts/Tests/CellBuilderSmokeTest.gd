extends SceneTree


# ============================================================
# АВТОМАТИЧЕСКАЯ ПРОВЕРКА CELL BUILDER
# ============================================================

const BUILDER_SCENE: PackedScene = preload(
	"res://Scense/Tools/CellBuilder/cell_builder.tscn"
)

const TEST_RESOURCE_PATH := (
	"res://Resources/Arenas/CellVisuals/Created/"
	+ "_cell_builder_smoke_test.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_remove_old_test_resource()

	var builder := BUILDER_SCENE.instantiate() as CellBuilder

	assert(builder != null)

	root.add_child(builder)
	await process_frame

	builder.cell_visual_id_edit.text = "cell_builder_smoke_test"
	builder.display_name_edit.text = "Cell Builder Smoke Test"
	builder.description_edit.text = (
		"Автоматически созданный тестовый ресурс."
	)

	builder._load_texture_into_slot(
		"res://icon.svg",
		"base"
	)
	builder.modulate_picker.color = Color(0.7, 0.8, 0.9, 1.0)
	builder.rotation_option.select(1)
	builder.flip_h_check.button_pressed = true
	builder._refresh_preview()

	assert(builder.preview_base.visible)
	assert(builder.preview_base.texture != null)
	assert(is_equal_approx(builder.preview_base.rotation, PI * 0.5))

	var cell_visual := builder._build_cell_visual_data()
	var report := CellVisualValidator.validate(cell_visual)

	assert(bool(report["is_valid"]))

	builder._save_cell_visual_to_path(
		cell_visual,
		TEST_RESOURCE_PATH
	)

	assert(FileAccess.file_exists(TEST_RESOURCE_PATH))

	var loaded_resource := ResourceLoader.load(
		TEST_RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	assert(loaded_resource is CellVisualData)

	var loaded_visual := loaded_resource as CellVisualData

	assert(
		loaded_visual.cell_visual_id
		== "cell_builder_smoke_test"
	)
	assert(loaded_visual.base_texture != null)
	assert(loaded_visual.quarter_turns == 1)
	assert(loaded_visual.flip_h)
	assert(not loaded_visual.flip_v)

	var saved_report := CellVisualValidator.validate(
		loaded_visual,
		TEST_RESOURCE_PATH
	)

	assert(bool(saved_report["is_valid"]))

	print(
		"CellBuilderSmokeTest: PASS — create, preview, validate, "
		+ "save and load completed"
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
