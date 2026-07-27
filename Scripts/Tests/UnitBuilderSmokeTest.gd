extends SceneTree


# ============================================================
# АВТОМАТИЧЕСКАЯ ПРОВЕРКА UNIT BUILDER
# ============================================================

const BUILDER_SCENE: PackedScene = preload(
	"res://Scense/Tools/UnitBuilder/unit_builder.tscn"
)

const TEST_RESOURCE_PATH := (
	"res://Resources/Unit/Created/"
	+ "_unit_builder_smoke_test.tres"
)


func _initialize() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	_remove_old_test_resource()

	var builder := BUILDER_SCENE.instantiate() as UnitBuilder

	assert(builder != null)

	root.add_child(builder)
	await process_frame

	builder.unit_id_edit.text = "unit_builder_smoke_test"
	builder.unit_name_edit.text = "Unit Builder Smoke Test"
	builder.max_hp_spin.value = 12
	builder.armor_spin.value = 2
	builder.movement_spin.value = 3

	builder._load_texture_into_slot(
		"res://icon.svg",
		"portrait"
	)
	builder._load_texture_into_slot(
		"res://icon.svg",
		"battlefield"
	)

	assert(builder.preview_unit.visible)
	assert(builder.preview_unit.static_sprite.visible)
	assert(builder.preview_unit.static_sprite.texture != null)

	var test_ability := ResourceLoader.load(
		"res://Resources/Abilities/UnitAbilityData/"
		+ "LongbowShot.tres"
	) as UnitAbilityData

	assert(test_ability != null)

	builder._active_abilities.append(test_ability)

	var unit_data := builder._build_unit_data()
	var report := UnitValidator.validate(unit_data)

	assert(bool(report["is_valid"]))

	builder._save_unit_to_path(
		unit_data,
		TEST_RESOURCE_PATH
	)

	assert(FileAccess.file_exists(TEST_RESOURCE_PATH))

	var loaded_resource := ResourceLoader.load(
		TEST_RESOURCE_PATH,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	assert(loaded_resource is UnitData)

	var loaded_unit := loaded_resource as UnitData

	assert(loaded_unit.unit_id == "unit_builder_smoke_test")
	assert(loaded_unit.max_hp == 12)
	assert(loaded_unit.visual_data != null)
	assert(loaded_unit.visual_data.portrait != null)
	assert(loaded_unit.visual_data.battlefield_texture != null)
	assert(loaded_unit.active_abilities.size() == 1)
	assert(loaded_unit.active_abilities[0] != null)

	var saved_report := UnitValidator.validate(
		loaded_unit,
		TEST_RESOURCE_PATH
	)

	assert(bool(saved_report["is_valid"]))

	print(
		"UnitBuilderSmokeTest: PASS — create, validate, "
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
