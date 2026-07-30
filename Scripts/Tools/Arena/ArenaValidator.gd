extends RefCounted

class_name ArenaValidator


# ============================================================
# ПУБЛИЧНАЯ ПРОВЕРКА
# ============================================================

static func validate(
	arena_data: ArenaData,
	current_resource_path: String = ""
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
	_validate_background(arena_data, errors, warnings)
	_validate_objects(arena_data, errors, warnings)

	var resolved_current_path := current_resource_path

	if (
		resolved_current_path.is_empty()
		and not arena_data.resource_path.is_empty()
	):
		resolved_current_path = arena_data.resource_path

	var duplicate_path := _find_duplicate_arena_id(
		arena_data.arena_id,
		resolved_current_path
	)

	if not duplicate_path.is_empty():
		errors.append(
			"Технический ID уже используется ресурсом: "
			+ duplicate_path
		)

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
	elif not _is_valid_technical_id(arena_data.arena_id):
		errors.append(
			"Технический ID должен начинаться со строчной латинской "
			+ "буквы и содержать только a-z, 0-9 и _."
		)

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
			errors.append(
				"Визуальный каркас заполнен не полностью. "
				+ "Каждая из 35 клеток должна иметь CellVisualData."
			)

	for y in range(arena_data.height):
		for x in range(arena_data.width):
			if arena_data.get_cell_visual_at(x, y) == null:
				errors.append(
					"Клетка %s не имеет визуала."
					% _coordinate_key(x, y)
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

	if (
		arena_data.player_1_deployment_capacity < 1
		or arena_data.player_1_deployment_capacity > 6
	):
		errors.append(
			"Вместимость расстановки игрока 1 должна быть от 1 до 6."
		)

	if (
		arena_data.player_2_deployment_capacity < 1
		or arena_data.player_2_deployment_capacity > 6
	):
		errors.append(
			"Вместимость расстановки игрока 2 должна быть от 1 до 6."
		)

	var player_1_count := 0
	var player_2_count := 0

	for y in range(arena_data.height):
		for x in range(arena_data.width):
			var zone := arena_data.get_zone_at(x, y)

			if (
				zone
				== ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
			):
				player_1_count += 1
			elif (
				zone
				== ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT
			):
				player_2_count += 1

	if player_1_count != arena_data.player_1_deployment_capacity:
		errors.append(
			"Расстановка игрока 1: размещено %d из %d клеток."
			% [
				player_1_count,
				arena_data.player_1_deployment_capacity
			]
		)

	if player_2_count != arena_data.player_2_deployment_capacity:
		errors.append(
			"Расстановка игрока 2: размещено %d из %d клеток."
			% [
				player_2_count,
				arena_data.player_2_deployment_capacity
			]
		)


# ============================================================
# ЗАДНИК
# ============================================================

static func _validate_background(
	arena_data: ArenaData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	if arena_data.background_scale.x <= 0.0:
		errors.append("Масштаб задника по X должен быть больше нуля.")

	if arena_data.background_scale.y <= 0.0:
		errors.append("Масштаб задника по Y должен быть больше нуля.")

	if (
		arena_data.background_texture == null
		and arena_data.background_color.a <= 0.0
	):
		warnings.append(
			"У арены нет ни изображения, ни видимого цвета задника."
		)


# ============================================================
# ОБЪЕКТЫ АРЕНЫ
# ============================================================

static func _validate_objects(
	arena_data: ArenaData,
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> void:
	for placement in arena_data.object_placements:
		if placement == null:
			errors.append(
				"В списке объектов арены есть пустое размещение."
			)
			continue

		if not _is_inside(arena_data, placement.x, placement.y):
			errors.append(
				"Объект арены %s находится за границами поля."
				% _coordinate_key(placement.x, placement.y)
			)

		if placement.object_data == null:
			warnings.append(
				"Размещение объекта %s пока не имеет ArenaObjectData."
				% _coordinate_key(placement.x, placement.y)
			)


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


static func _is_valid_technical_id(technical_id: String) -> bool:
	var expression := RegEx.new()

	if expression.compile("^[a-z][a-z0-9_]*$") != OK:
		return false

	return expression.search(technical_id.strip_edges()) != null


static func _find_duplicate_arena_id(
	arena_id: String,
	current_resource_path: String
) -> String:
	if arena_id.strip_edges().is_empty():
		return ""

	var resource_paths := PackedStringArray()
	_collect_resource_paths(
		"res://Resources/Arenas/Arenas",
		resource_paths
	)

	for resource_path in resource_paths:
		if resource_path == current_resource_path:
			continue

		var loaded_resource := ResourceLoader.load(resource_path)

		if not loaded_resource is ArenaData:
			continue

		if (loaded_resource as ArenaData).arena_id == arena_id:
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


static func _make_result(
	errors: PackedStringArray,
	warnings: PackedStringArray
) -> Dictionary:
	return {
		"errors": errors,
		"warnings": warnings,
		"is_valid": errors.is_empty()
	}
