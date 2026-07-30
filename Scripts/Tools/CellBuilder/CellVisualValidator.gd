extends RefCounted

class_name CellVisualValidator


# ============================================================
# КОНСТАНТЫ
# ============================================================

const CELL_VISUAL_DIRECTORY := "res://Resources/Arenas/CellVisuals"


# ============================================================
# ПУБЛИЧНАЯ ВАЛИДАЦИЯ
# ============================================================

static func validate(
	cell_visual: CellVisualData,
	current_resource_path: String = ""
) -> Dictionary:
	var errors := PackedStringArray()
	var warnings := PackedStringArray()

	if cell_visual == null:
		errors.append("Данные визуальной клетки не созданы.")
		return _make_report(errors, warnings)

	_validate_identity(cell_visual, errors)
	_validate_textures(cell_visual, errors, warnings)
	_validate_variation(cell_visual, errors, warnings)

	var duplicate_path := _find_duplicate_cell_visual_id(
		cell_visual.cell_visual_id,
		current_resource_path
	)

	if not duplicate_path.is_empty():
		errors.append(
			"Технический ID уже используется ресурсом: "
			+ duplicate_path
		)

	return _make_report(errors, warnings)


# ============================================================
# ИДЕНТИФИКАЦИЯ
# ============================================================

static func _validate_identity(
	cell_visual: CellVisualData,
	errors: PackedStringArray
) -> void:
	var technical_id := cell_visual.cell_visual_id.strip_edges()

	if technical_id.is_empty():
		errors.append("Укажи технический ID визуальной клетки.")
	elif not _is_valid_technical_id(technical_id):
		errors.append(
			"Технический ID должен начинаться со строчной латинской "
			+ "буквы и содержать только a-z, 0-9 и _. "
			+ "Пример: stone_floor."
		)

	if cell_visual.display_name.strip_edges().is_empty():
		errors.append("Укажи отображаемое название визуальной клетки.")


static func _is_valid_technical_id(technical_id: String) -> bool:
	var expression := RegEx.new()
	var compile_error := expression.compile(
		"^[a-z][a-z0-9_]*$"
	)

	if compile_error != OK:
		return false

	return expression.search(technical_id) != null


# ============================================================
# ТЕКСТУРЫ
# ============================================================

static func _validate_textures(
	cell_visual: CellVisualData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	if (
		cell_visual.base_texture == null
		and cell_visual.decoration_texture == null
	):
		errors.append(
			"Назначь базовую или декоративную текстуру. "
			+ "Пустой CellVisualData ничего не показывает."
		)
		return

	if (
		cell_visual.base_texture == null
		and cell_visual.decoration_texture != null
	):
		warnings.append(
			"Базовая текстура не назначена. Декорация будет "
			+ "показана поверх фона арены."
		)

	if cell_visual.modulate.a <= 0.0:
		warnings.append(
			"Альфа цвета равна нулю: обе текстуры будут невидимы."
		)


# ============================================================
# ВАРИАЦИЯ
# ============================================================

static func _validate_variation(
	cell_visual: CellVisualData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	if cell_visual.quarter_turns < 0 or cell_visual.quarter_turns > 3:
		errors.append(
			"Поворот должен быть задан числом четвертей от 0 до 3."
		)

	if (
		cell_visual.base_texture != null
		and cell_visual.decoration_texture != null
		and cell_visual.base_texture == cell_visual.decoration_texture
	):
		warnings.append(
			"Базовая и декоративная текстуры совпадают. "
			+ "Они будут нарисованы друг поверх друга."
		)


# ============================================================
# УНИКАЛЬНОСТЬ ID
# ============================================================

static func _find_duplicate_cell_visual_id(
	cell_visual_id: String,
	current_resource_path: String
) -> String:
	if cell_visual_id.strip_edges().is_empty():
		return ""

	var resource_paths := PackedStringArray()

	_collect_resource_paths(
		CELL_VISUAL_DIRECTORY,
		resource_paths
	)

	for resource_path in resource_paths:
		if resource_path == current_resource_path:
			continue

		var loaded_resource := ResourceLoader.load(resource_path)

		if not loaded_resource is CellVisualData:
			continue

		var other_visual := loaded_resource as CellVisualData

		if other_visual.cell_visual_id == cell_visual_id:
			return resource_path

	return ""


static func _collect_resource_paths(
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

		var full_path := directory_path.path_join(file_name)

		if directory.current_is_dir():
			_collect_resource_paths(full_path, result)
		elif file_name.get_extension().to_lower() in ["tres", "res"]:
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
