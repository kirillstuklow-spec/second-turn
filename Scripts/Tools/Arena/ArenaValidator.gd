extends RefCounted

class_name ArenaValidator


# ============================================================
# ПУБЛИЧНАЯ ПРОВЕРКА
# ============================================================

static func validate(
	arena_data: ArenaData
) -> Dictionary:
	var errors: PackedStringArray = []
	var warnings: PackedStringArray = []

	if arena_data == null:
		errors.append("ArenaData не назначена.")
		return _make_result(errors, warnings)

	_validate_identity(arena_data, errors)
	_validate_size(arena_data, errors)
	_validate_visuals(arena_data, errors, warnings)
	_validate_zones(arena_data, errors)

	return _make_result(errors, warnings)


# ============================================================
# ИДЕНТИФИКАЦИЯ
# ============================================================

static func _validate_identity(
	arena_data: ArenaData,
	errors: PackedStringArray
) -> void:
	if arena_data.arena_id.strip_edges().is_empty():
		errors.append("Не заполнен технический ID арены.")

	if arena_data.arena_name.strip_edges().is_empty():
		errors.append("Не заполнено название арены.")


# ============================================================
# РАЗМЕР
# ============================================================

static func _validate_size(
	arena_data: ArenaData,
	errors: PackedStringArray
) -> void:
	if arena_data.width <= 0 or arena_data.height <= 0:
		errors.append("Размер арены должен быть больше нуля.")
		return

	if arena_data.width != 7 or arena_data.height != 5:
		errors.append(
			"Текущая версия поддерживает только арену размером 7×5."
		)


# ============================================================
# ВИЗУАЛЬНЫЙ СЛОЙ
# ============================================================

static func _validate_visuals(
	arena_data: ArenaData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	var used_coordinates: Dictionary = {}

	for placement in arena_data.visual_placements:
		if placement == null:
			errors.append(
				"В списке визуальных клеток есть пустая ссылка."
			)
			continue

		var coordinate_key := _coordinate_key(
			placement.x,
			placement.y
		)

		if not _is_inside(
			arena_data,
			placement.x,
			placement.y
		):
			errors.append(
				"Визуальная клетка %s находится за границами арены."
				% coordinate_key
			)
			continue

		if used_coordinates.has(coordinate_key):
			errors.append(
				"Визуал клетки %s задан больше одного раза."
				% coordinate_key
			)
			continue

		used_coordinates[coordinate_key] = true

		if placement.cell_visual == null:
			errors.append(
				"Для визуальной клетки %s не назначен CellVisualData."
				% coordinate_key
			)

	var default_visual := arena_data.default_cell_visual

	if default_visual == null and arena_data.biome != null:
		default_visual = arena_data.biome.default_cell_visual

	if default_visual == null:
		var expected_count := arena_data.width * arena_data.height

		if used_coordinates.size() < expected_count:
			warnings.append(
				"Не все клетки имеют визуал. "
				+ "Для остальных будет использована цветная заглушка."
			)


# ============================================================
# ЛОГИЧЕСКИЙ СЛОЙ ЗОН
# ============================================================

static func _validate_zones(
	arena_data: ArenaData,
	errors: PackedStringArray
) -> void:
	var used_coordinates: Dictionary = {}

	for placement in arena_data.zone_placements:
		if placement == null:
			errors.append(
				"В списке зон есть пустая ссылка."
			)
			continue

		var coordinate_key := _coordinate_key(
			placement.x,
			placement.y
		)

		if not _is_inside(
			arena_data,
			placement.x,
			placement.y
		):
			errors.append(
				"Зона клетки %s находится за границами арены."
				% coordinate_key
			)
			continue

		if used_coordinates.has(coordinate_key):
			errors.append(
				"Зона клетки %s задана больше одного раза."
				% coordinate_key
			)
			continue

		used_coordinates[coordinate_key] = true


# ============================================================
# ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================

static func _is_inside(
	arena_data: ArenaData,
	x: int,
	y: int
) -> bool:
	return (
		x >= 0
		and x < arena_data.width
		and y >= 0
		and y < arena_data.height
	)


static func _coordinate_key(
	x: int,
	y: int
) -> String:
	return "%d,%d" % [x, y]


static func _make_result(
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> Dictionary:
	return {
		"errors": errors,
		"warnings": warnings,
		"is_valid": errors.is_empty()
	}
