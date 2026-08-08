extends RefCounted

class_name UnitValidator


# ============================================================
# ПУБЛИЧНАЯ ВАЛИДАЦИЯ
# ============================================================

static func validate(
	unit_data: UnitData,
	current_resource_path: String = ""
) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()

	if unit_data == null:
		errors.append("Данные юнита не созданы.")
		return _make_report(errors, warnings)

	_validate_identity(unit_data, errors)
	_validate_stats(unit_data, errors)
	_validate_keywords(unit_data, warnings)
	_validate_abilities(unit_data, errors, warnings)
	_validate_visuals(unit_data, errors, warnings)

	var duplicate_path := _find_duplicate_unit_id(
		unit_data.unit_id,
		current_resource_path
	)

	if not duplicate_path.is_empty():
		errors.append(
			"Технический ID уже используется ресурсом: "
			+ duplicate_path
		)

	return _make_report(errors, warnings)


# ============================================================
# ОСНОВНЫЕ ДАННЫЕ
# ============================================================

static func _validate_identity(
	unit_data: UnitData,
	errors: PackedStringArray
) -> void:
	var technical_id := unit_data.unit_id.strip_edges()

	if technical_id.is_empty():
		errors.append("Укажи технический ID юнита.")
	elif not _is_valid_technical_id(technical_id):
		errors.append(
			"Технический ID должен начинаться со строчной латинской "
			+ "буквы и содержать только a-z, 0-9 и _. "
			+ "Пример: white_prophet."
		)

	if unit_data.unit_name.strip_edges().is_empty():
		errors.append("Укажи отображаемое имя юнита.")


static func _is_valid_technical_id(technical_id: String) -> bool:
	var expression := RegEx.new()
	var compile_error := expression.compile(
		"^[a-z][a-z0-9_]*$"
	)

	if compile_error != OK:
		return false

	return expression.search(technical_id) != null


# ============================================================
# ХАРАКТЕРИСТИКИ
# ============================================================

static func _validate_stats(
	unit_data: UnitData,
	errors: PackedStringArray
) -> void:
	if unit_data.max_hp <= 0:
		errors.append("Максимальное здоровье должно быть больше 0.")

	if unit_data.armor < 0 or unit_data.armor > 5:
		errors.append("Броня должна находиться в диапазоне от 0 до 5.")

	if unit_data.movement < 0:
		errors.append("Скорость не может быть отрицательной.")

	if not [
		UnitData.UnitSize.NORMAL,
		UnitData.UnitSize.LARGE,
		UnitData.UnitSize.HUGE
	].has(unit_data.size):
		errors.append("Выбран неизвестный размер юнита.")


# ============================================================
# КЛЮЧЕВЫЕ СЛОВА
# ============================================================

static func _validate_keywords(
	unit_data: UnitData,
	warnings: PackedStringArray
) -> void:
	_warn_about_duplicates(
		unit_data.defenses,
		"защитах",
		warnings
	)
	_warn_about_duplicates(
		unit_data.immunities,
		"иммунитетах",
		warnings
	)
	_warn_about_duplicates(
		unit_data.keywords,
		"ключевых словах",
		warnings
	)


static func _warn_about_duplicates(
	values: Array[String],
	field_name: String,
	warnings: PackedStringArray
) -> void:
	var unique_values: Dictionary = {}

	for value in values:
		var normalized_value := value.strip_edges()

		if normalized_value.is_empty():
			continue

		if unique_values.has(normalized_value):
			warnings.append(
				"В %s повторяется значение '%s'." % [
					field_name,
					normalized_value
				]
			)
			return

		unique_values[normalized_value] = true


# ============================================================
# СПОСОБНОСТИ
# ============================================================

static func _validate_abilities(
	unit_data: UnitData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	var algorithm_registry := AbilityAlgorithmRegistry.new()

	for ability_index in range(
		unit_data.active_abilities.size()
	):
		var active_ability := unit_data.active_abilities[ability_index]

		if active_ability == null:
			errors.append(
				"Активная способность №%d не назначена." % (
					ability_index + 1
				)
			)
			continue

		_validate_ability_schema(
			active_ability,
			"Активная способность №%d" % (ability_index + 1),
			algorithm_registry,
			errors
		)

		if (
			active_ability.ability != null
			and active_ability.ability.activation_mode
			!= AbilityData.ActivationMode.ACTIVE
		):
			errors.append(
				"Активная способность №%d должна иметь activation_mode=ACTIVE."
				% (ability_index + 1)
			)

	for ability_index in range(
		unit_data.passive_abilities.size()
	):
		var passive_ability := unit_data.passive_abilities[ability_index]

		if passive_ability == null:
			errors.append(
				"Пассивная способность №%d не назначена." % (
					ability_index + 1
				)
			)
			continue

		_validate_ability_schema(
			passive_ability,
			"Пассивная способность №%d" % (ability_index + 1),
			algorithm_registry,
			errors
		)

		if (
			passive_ability.ability != null
			and passive_ability.ability.activation_mode
			== AbilityData.ActivationMode.ACTIVE
		):
			errors.append(
				"Пассивная способность №%d не может иметь activation_mode=ACTIVE."
				% (ability_index + 1)
			)

	if unit_data.active_abilities.size() > 6:
		warnings.append(
			"Боевой интерфейс показывает только первые 6 "
			+ "активных способностей."
		)

static func _validate_ability_schema(
	unit_ability: UnitAbilityData,
	ability_label: String,
	algorithm_registry: AbilityAlgorithmRegistry,
	errors: PackedStringArray
) -> void:
	var schema_result := algorithm_registry.validate_unit_ability(
		unit_ability
	)

	if schema_result.is_valid:
		return

	errors.append(
		"%s содержит ошибку схемы:\n%s" % [
			ability_label,
			schema_result.get_summary()
		]
	)


# ============================================================
# ВИЗУАЛ
# ============================================================

static func _validate_visuals(
	unit_data: UnitData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	var visual_data := unit_data.visual_data

	if visual_data == null:
		warnings.append(
			"Визуальные данные не назначены. "
			+ "В бою будет показана текстовая заглушка."
		)
		return

	if (
		not is_finite(visual_data.visual_scale.x)
		or not is_finite(visual_data.visual_scale.y)
		or visual_data.visual_scale.x <= 0.0
		or visual_data.visual_scale.y <= 0.0
	):
		errors.append(
			"Масштаб визуала должен состоять из двух "
			+ "положительных конечных чисел."
		)

	if (
		not is_finite(visual_data.cell_offset.x)
		or not is_finite(visual_data.cell_offset.y)
	):
		errors.append(
			"Смещение визуала должно состоять из конечных чисел."
		)

	_validate_sprite_frames(
		visual_data.idle_frames,
		"idle",
		errors
	)
	_validate_sprite_frames(
		visual_data.move_frames,
		"move",
		errors
	)
	_validate_sprite_frames(
		visual_data.block_frames,
		"block",
		errors
	)
	_validate_sprite_frames(
		visual_data.hit_frames,
		"hit",
		errors
	)
	_validate_sprite_frames(
		visual_data.death_frames,
		"death",
		errors
	)

	if (
		visual_data.battlefield_texture == null
		and visual_data.idle_frames == null
	):
		warnings.append(
			"Не назначены ни изображение на поле, ни idle-анимация. "
			+ "В бою будет показана текстовая заглушка."
		)

	if visual_data.portrait == null:
		warnings.append(
			"Портрет не назначен. Панель юнита останется без портрета."
		)


static func _validate_sprite_frames(
	frames: SpriteFrames,
	slot_name: String,
	errors: PackedStringArray
) -> void:
	if frames == null:
		return

	if not frames.has_animation(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	):
		errors.append(
			"В слоте %s нет анимации '%s'." % [
				slot_name,
				String(UnitVisualData.REQUIRED_ANIMATION_NAME)
			]
		)
		return

	if frames.get_frame_count(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	) <= 0:
		errors.append(
			"В анимации '%s' слота %s нет кадров." % [
				String(UnitVisualData.REQUIRED_ANIMATION_NAME),
				slot_name
			]
		)


# ============================================================
# УНИКАЛЬНОСТЬ ID
# ============================================================

static func _find_duplicate_unit_id(
	unit_id: String,
	current_resource_path: String
) -> String:
	if unit_id.strip_edges().is_empty():
		return ""

	var unit_resource_paths := PackedStringArray()

	_collect_unit_resource_paths(
		"res://Resources/Unit",
		unit_resource_paths
	)

	for resource_path in unit_resource_paths:
		if resource_path == current_resource_path:
			continue

		var loaded_resource := ResourceLoader.load(
			resource_path
		)

		if not loaded_resource is UnitData:
			continue

		var other_unit := loaded_resource as UnitData

		if other_unit.unit_id == unit_id:
			return resource_path

	return ""


static func _collect_unit_resource_paths(
	directory_path: String,
	result: PackedStringArray
) -> void:
	var directory := DirAccess.open(directory_path)

	if directory == null:
		return

	directory.list_dir_begin()

	var file_name := directory.get_next()

	while not file_name.is_empty():
		if file_name.begins_with("."):
			file_name = directory.get_next()
			continue

		var full_path := directory_path.path_join(
			file_name
		)

		if directory.current_is_dir():
			_collect_unit_resource_paths(
				full_path,
				result
			)
		elif (
			file_name.get_extension().to_lower() == "tres"
			or file_name.get_extension().to_lower() == "res"
		):
			result.append(full_path)

		file_name = directory.get_next()

	directory.list_dir_end()


# ============================================================
# ОТЧЁТ
# ============================================================

static func _make_report(
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> Dictionary:
	return {
		"errors": errors,
		"warnings": warnings,
		"is_valid": errors.is_empty()
	}
