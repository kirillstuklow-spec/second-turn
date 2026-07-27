extends Control

class_name UnitBuilder


# ============================================================
# КОНСТАНТЫ И РЕЖИМЫ FILE DIALOG
# ============================================================

const UNIT_DIRECTORY := "res://Resources/Unit"
const CREATED_UNIT_DIRECTORY := "res://Resources/Unit/Created"

const UNIT_FILTER := "*.tres, *.res ; UnitData resources"
const TEXTURE_FILTER := (
	"*.png, *.jpg, *.jpeg, *.webp, *.svg ; Image textures"
)
const RESOURCE_FILTER := "*.tres, *.res ; Godot resources"


enum FileRequest {
	NONE,
	OPEN_UNIT,
	SAVE_UNIT,
	ADD_ACTIVE_ABILITY,
	ADD_PASSIVE_ABILITY,
	PORTRAIT,
	BATTLEFIELD_TEXTURE,
	IDLE_FRAMES,
	MOVE_FRAMES,
	BLOCK_FRAMES,
	HIT_FRAMES,
	DEATH_FRAMES
}


# ============================================================
# ОСНОВНЫЕ ЭЛЕМЕНТЫ ИНТЕРФЕЙСА
# ============================================================

@onready var new_button: Button = %NewButton
@onready var open_button: Button = %OpenButton
@onready var save_button: Button = %SaveButton
@onready var save_as_button: Button = %SaveAsButton
@onready var validate_button: Button = %ValidateButton
@onready var current_path_label: Label = %CurrentPathLabel

@onready var unit_id_edit: LineEdit = %UnitIdEdit
@onready var unit_name_edit: LineEdit = %UnitNameEdit
@onready var description_edit: TextEdit = %DescriptionEdit
@onready var faction_edit: LineEdit = %FactionEdit
@onready var unit_class_edit: LineEdit = %UnitClassEdit
@onready var experience_spin: SpinBox = %ExperienceSpin

@onready var initiative_spin: SpinBox = %InitiativeSpin
@onready var max_hp_spin: SpinBox = %MaxHPSpin
@onready var armor_spin: SpinBox = %ArmorSpin
@onready var movement_spin: SpinBox = %MovementSpin
@onready var size_option: OptionButton = %SizeOption

@onready var defenses_edit: LineEdit = %DefensesEdit
@onready var immunities_edit: LineEdit = %ImmunitiesEdit
@onready var keywords_edit: LineEdit = %KeywordsEdit

@onready var active_ability_list: ItemList = %ActiveAbilityList
@onready var passive_ability_list: ItemList = %PassiveAbilityList
@onready var add_active_button: Button = %AddActiveButton
@onready var remove_active_button: Button = %RemoveActiveButton
@onready var add_passive_button: Button = %AddPassiveButton
@onready var remove_passive_button: Button = %RemovePassiveButton

@onready var portrait_path: LineEdit = %PortraitPath
@onready var battlefield_path: LineEdit = %BattlefieldPath
@onready var idle_frames_path: LineEdit = %IdleFramesPath
@onready var move_frames_path: LineEdit = %MoveFramesPath
@onready var block_frames_path: LineEdit = %BlockFramesPath
@onready var hit_frames_path: LineEdit = %HitFramesPath
@onready var death_frames_path: LineEdit = %DeathFramesPath

@onready var choose_portrait_button: Button = %ChoosePortraitButton
@onready var clear_portrait_button: Button = %ClearPortraitButton
@onready var choose_battlefield_button: Button = %ChooseBattlefieldButton
@onready var clear_battlefield_button: Button = %ClearBattlefieldButton
@onready var choose_idle_button: Button = %ChooseIdleButton
@onready var clear_idle_button: Button = %ClearIdleButton
@onready var choose_move_button: Button = %ChooseMoveButton
@onready var clear_move_button: Button = %ClearMoveButton
@onready var choose_block_button: Button = %ChooseBlockButton
@onready var clear_block_button: Button = %ClearBlockButton
@onready var choose_hit_button: Button = %ChooseHitButton
@onready var clear_hit_button: Button = %ClearHitButton
@onready var choose_death_button: Button = %ChooseDeathButton
@onready var clear_death_button: Button = %ClearDeathButton

@onready var scale_x_spin: SpinBox = %ScaleXSpin
@onready var scale_y_spin: SpinBox = %ScaleYSpin
@onready var offset_x_spin: SpinBox = %OffsetXSpin
@onready var offset_y_spin: SpinBox = %OffsetYSpin

@onready var preview_unit: UnitView = %PreviewUnit
@onready var status_output: RichTextLabel = %StatusOutput
@onready var file_dialog: FileDialog = %FileDialog


# ============================================================
# РЕДАКТИРУЕМЫЕ ССЫЛКИ
# ============================================================

var _current_resource_path := ""
var _file_request := FileRequest.NONE

var _active_abilities: Array[UnitAbilityData] = []
var _passive_abilities: Array[UnitAbilityData] = []

var _portrait: Texture2D = null
var _battlefield_texture: Texture2D = null
var _idle_frames: SpriteFrames = null
var _move_frames: SpriteFrames = null
var _block_frames: SpriteFrames = null
var _hit_frames: SpriteFrames = null
var _death_frames: SpriteFrames = null


# ============================================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================================

func _ready() -> void:
	get_window().min_size = Vector2i(1080, 680)

	_ensure_content_directory()
	_populate_size_options()
	_connect_controls()
	_start_new_unit()


func _ensure_content_directory() -> void:
	var absolute_path := ProjectSettings.globalize_path(
		CREATED_UNIT_DIRECTORY
	)
	var error := DirAccess.make_dir_recursive_absolute(
		absolute_path
	)

	if error != OK and error != ERR_ALREADY_EXISTS:
		push_warning(
			"UnitBuilder: could not create directory "
			+ CREATED_UNIT_DIRECTORY
		)


func _populate_size_options() -> void:
	size_option.clear()

	size_option.add_item("Обычный — 1 клетка")
	size_option.set_item_metadata(
		0,
		UnitData.UnitSize.NORMAL
	)

	size_option.add_item("Большой — 2 клетки")
	size_option.set_item_metadata(
		1,
		UnitData.UnitSize.LARGE
	)

	size_option.add_item("Огромный — 4 клетки")
	size_option.set_item_metadata(
		2,
		UnitData.UnitSize.HUGE
	)


func _connect_controls() -> void:
	new_button.pressed.connect(_start_new_unit)
	open_button.pressed.connect(_request_open_unit)
	save_button.pressed.connect(_request_save)
	save_as_button.pressed.connect(
		_request_save.bind(true)
	)
	validate_button.pressed.connect(_validate_form)

	add_active_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.ADD_ACTIVE_ABILITY
		)
	)
	remove_active_button.pressed.connect(
		_remove_selected_active_abilities
	)
	add_passive_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.ADD_PASSIVE_ABILITY
		)
	)
	remove_passive_button.pressed.connect(
		_remove_selected_passive_abilities
	)

	choose_portrait_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.PORTRAIT
		)
	)
	clear_portrait_button.pressed.connect(
		_clear_visual_slot.bind("portrait")
	)
	choose_battlefield_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.BATTLEFIELD_TEXTURE
		)
	)
	clear_battlefield_button.pressed.connect(
		_clear_visual_slot.bind("battlefield")
	)
	choose_idle_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.IDLE_FRAMES
		)
	)
	clear_idle_button.pressed.connect(
		_clear_visual_slot.bind("idle")
	)
	choose_move_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.MOVE_FRAMES
		)
	)
	clear_move_button.pressed.connect(
		_clear_visual_slot.bind("move")
	)
	choose_block_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.BLOCK_FRAMES
		)
	)
	clear_block_button.pressed.connect(
		_clear_visual_slot.bind("block")
	)
	choose_hit_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.HIT_FRAMES
		)
	)
	clear_hit_button.pressed.connect(
		_clear_visual_slot.bind("hit")
	)
	choose_death_button.pressed.connect(
		_open_file_request.bind(
			FileRequest.DEATH_FRAMES
		)
	)
	clear_death_button.pressed.connect(
		_clear_visual_slot.bind("death")
	)

	file_dialog.file_selected.connect(
		_on_file_selected
	)

	unit_name_edit.text_changed.connect(
		_on_preview_text_changed
	)
	scale_x_spin.value_changed.connect(
		_on_preview_value_changed
	)
	scale_y_spin.value_changed.connect(
		_on_preview_value_changed
	)
	offset_x_spin.value_changed.connect(
		_on_preview_value_changed
	)
	offset_y_spin.value_changed.connect(
		_on_preview_value_changed
	)


# ============================================================
# НОВЫЙ И ОТКРЫТЫЙ ЮНИТ
# ============================================================

func _start_new_unit() -> void:
	_current_resource_path = ""
	_populate_form(UnitData.new())
	_set_status_message(
		"[color=#8fd3ff]Новый юнит. "
		+ "Заполни обязательные поля и нажми «Проверить».[/color]"
	)


func _request_open_unit() -> void:
	_open_file_request(FileRequest.OPEN_UNIT)


func _load_unit_from_path(path: String) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if not (loaded_resource is UnitData):
		_set_status_error(
			"Выбранный ресурс не является UnitData: " + path
		)
		return

	_current_resource_path = path
	_populate_form(loaded_resource as UnitData)
	_set_status_message(
		"[color=#8fd3ff]Открыт юнит:[/color] " + path
	)


func _populate_form(unit_data: UnitData) -> void:
	unit_id_edit.text = unit_data.unit_id
	unit_name_edit.text = unit_data.unit_name
	description_edit.text = unit_data.description
	faction_edit.text = unit_data.faction
	unit_class_edit.text = unit_data.unit_class
	experience_spin.value = unit_data.experience_to_level

	initiative_spin.value = unit_data.initiative
	max_hp_spin.value = unit_data.max_hp
	armor_spin.value = unit_data.armor
	movement_spin.value = unit_data.movement
	_select_size(unit_data.size)

	defenses_edit.text = _join_keywords(
		unit_data.defenses
	)
	immunities_edit.text = _join_keywords(
		unit_data.immunities
	)
	keywords_edit.text = _join_keywords(
		unit_data.keywords
	)

	_active_abilities.clear()
	for ability in unit_data.active_abilities:
		_active_abilities.append(ability)

	_passive_abilities.clear()
	for ability in unit_data.passive_abilities:
		_passive_abilities.append(ability)

	_reset_visual_references()

	if unit_data.visual_data != null:
		var visual_data := unit_data.visual_data

		_portrait = visual_data.portrait
		_battlefield_texture = visual_data.battlefield_texture
		_idle_frames = visual_data.idle_frames
		_move_frames = visual_data.move_frames
		_block_frames = visual_data.block_frames
		_hit_frames = visual_data.hit_frames
		_death_frames = visual_data.death_frames

		scale_x_spin.value = visual_data.visual_scale.x
		scale_y_spin.value = visual_data.visual_scale.y
		offset_x_spin.value = visual_data.cell_offset.x
		offset_y_spin.value = visual_data.cell_offset.y
	else:
		scale_x_spin.value = 1.0
		scale_y_spin.value = 1.0
		offset_x_spin.value = 0.0
		offset_y_spin.value = 0.0

	_refresh_ability_lists()
	_refresh_visual_paths()
	_refresh_current_path()
	_refresh_preview()


# ============================================================
# СБОРКА DATA ИЗ ФОРМЫ
# ============================================================

func _build_unit_data() -> UnitData:
	var unit_data := UnitData.new()

	unit_data.unit_id = unit_id_edit.text.strip_edges()
	unit_data.unit_name = unit_name_edit.text.strip_edges()
	unit_data.description = description_edit.text.strip_edges()
	unit_data.faction = faction_edit.text.strip_edges()
	unit_data.unit_class = unit_class_edit.text.strip_edges()
	unit_data.experience_to_level = int(
		experience_spin.value
	)

	unit_data.initiative = int(initiative_spin.value)
	unit_data.max_hp = int(max_hp_spin.value)
	unit_data.armor = int(armor_spin.value)
	unit_data.movement = int(movement_spin.value)
	unit_data.size = _get_selected_size()

	unit_data.defenses = _parse_keywords(
		defenses_edit.text
	)
	unit_data.immunities = _parse_keywords(
		immunities_edit.text
	)
	unit_data.keywords = _parse_keywords(
		keywords_edit.text
	)

	for ability in _active_abilities:
		unit_data.active_abilities.append(ability)

	for ability in _passive_abilities:
		unit_data.passive_abilities.append(ability)

	unit_data.visual_data = _build_visual_data()
	unit_data.resource_name = unit_data.unit_name

	return unit_data


func _build_visual_data() -> UnitVisualData:
	var visual_data := UnitVisualData.new()

	visual_data.portrait = _portrait
	visual_data.battlefield_texture = _battlefield_texture
	visual_data.idle_frames = _idle_frames
	visual_data.move_frames = _move_frames
	visual_data.block_frames = _block_frames
	visual_data.hit_frames = _hit_frames
	visual_data.death_frames = _death_frames

	visual_data.visual_scale = Vector2(
		float(scale_x_spin.value),
		float(scale_y_spin.value)
	)
	visual_data.cell_offset = Vector2(
		float(offset_x_spin.value),
		float(offset_y_spin.value)
	)

	return visual_data


# ============================================================
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ============================================================

func _validate_form() -> void:
	var report := UnitValidator.validate(
		_build_unit_data(),
		_current_resource_path
	)

	_show_validation_report(report)
	_refresh_preview()


func _request_save(save_as: bool = false) -> void:
	var unit_data := _build_unit_data()
	var report := UnitValidator.validate(
		unit_data,
		_current_resource_path
	)

	if not bool(report["is_valid"]):
		_show_validation_report(report)
		return

	if not save_as and not _current_resource_path.is_empty():
		_save_unit_to_path(
			unit_data,
			_current_resource_path
		)
		return

	_open_file_request(FileRequest.SAVE_UNIT)


func _save_unit_to_path(
	unit_data: UnitData,
	requested_path: String
) -> void:
	var save_path := requested_path

	if save_path.get_extension().to_lower() not in [
		"tres",
		"res"
	]:
		save_path += ".tres"

	if not save_path.begins_with(UNIT_DIRECTORY + "/"):
		_set_status_error(
			"Юниты следует сохранять внутри "
			+ UNIT_DIRECTORY
			+ "."
		)
		return

	var report := UnitValidator.validate(
		unit_data,
		save_path
	)

	if not bool(report["is_valid"]):
		_show_validation_report(report)
		return

	var absolute_directory := ProjectSettings.globalize_path(
		save_path.get_base_dir()
	)
	var directory_error := DirAccess.make_dir_recursive_absolute(
		absolute_directory
	)

	if (
		directory_error != OK
		and directory_error != ERR_ALREADY_EXISTS
	):
		_set_status_error(
			"Не удалось создать папку для сохранения: "
			+ save_path.get_base_dir()
		)
		return

	var save_error := ResourceSaver.save(
		unit_data,
		save_path
	)

	if save_error != OK:
		_set_status_error(
			"Godot не смог сохранить UnitData. Код ошибки: "
			+ str(save_error)
		)
		return

	_current_resource_path = save_path
	_refresh_current_path()

	var success_text := (
		"[color=#8cff9b]Юнит сохранён:[/color] "
		+ save_path
	)

	var warnings := report["warnings"] as PackedStringArray

	if not warnings.is_empty():
		success_text += "\n\n[color=#ffd27a]Предупреждения:[/color]"

		for warning in warnings:
			success_text += "\n• " + warning

	_set_status_message(success_text)


# ============================================================
# FILE DIALOG
# ============================================================

func _open_file_request(request: FileRequest) -> void:
	_file_request = request
	file_dialog.access = FileDialog.ACCESS_RESOURCES

	match request:
		FileRequest.OPEN_UNIT:
			file_dialog.title = "Открыть UnitData"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				UNIT_FILTER
			])
			file_dialog.current_dir = UNIT_DIRECTORY
		FileRequest.SAVE_UNIT:
			file_dialog.title = "Сохранить UnitData"
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = PackedStringArray([
				UNIT_FILTER
			])
			file_dialog.current_dir = CREATED_UNIT_DIRECTORY
			file_dialog.current_file = _suggest_file_name()
		FileRequest.PORTRAIT, FileRequest.BATTLEFIELD_TEXTURE:
			file_dialog.title = "Выбрать изображение"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				TEXTURE_FILTER
			])
			file_dialog.current_dir = "res://"
		FileRequest.ADD_ACTIVE_ABILITY, FileRequest.ADD_PASSIVE_ABILITY:
			file_dialog.title = "Выбрать UnitAbilityData"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				RESOURCE_FILTER
			])
			file_dialog.current_dir = (
				"res://Resources/Abilities/UnitAbilityData"
			)
		_:
			file_dialog.title = "Выбрать SpriteFrames"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				RESOURCE_FILTER
			])
			file_dialog.current_dir = "res://"

	file_dialog.popup_centered_ratio(0.82)


func _on_file_selected(path: String) -> void:
	var request := _file_request
	_file_request = FileRequest.NONE

	match request:
		FileRequest.OPEN_UNIT:
			_load_unit_from_path(path)
		FileRequest.SAVE_UNIT:
			_save_unit_to_path(
				_build_unit_data(),
				path
			)
		FileRequest.ADD_ACTIVE_ABILITY:
			_add_ability_from_path(path, true)
		FileRequest.ADD_PASSIVE_ABILITY:
			_add_ability_from_path(path, false)
		FileRequest.PORTRAIT:
			_load_texture_into_slot(path, "portrait")
		FileRequest.BATTLEFIELD_TEXTURE:
			_load_texture_into_slot(path, "battlefield")
		FileRequest.IDLE_FRAMES:
			_load_frames_into_slot(path, "idle")
		FileRequest.MOVE_FRAMES:
			_load_frames_into_slot(path, "move")
		FileRequest.BLOCK_FRAMES:
			_load_frames_into_slot(path, "block")
		FileRequest.HIT_FRAMES:
			_load_frames_into_slot(path, "hit")
		FileRequest.DEATH_FRAMES:
			_load_frames_into_slot(path, "death")


func _suggest_file_name() -> String:
	var technical_id := unit_id_edit.text.strip_edges()

	if technical_id.is_empty():
		return "new_unit.tres"

	return technical_id + ".tres"


# ============================================================
# СПОСОБНОСТИ
# ============================================================

func _add_ability_from_path(
	path: String,
	is_active: bool
) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if not (loaded_resource is UnitAbilityData):
		_set_status_error(
			"Выбранный ресурс не является UnitAbilityData: "
			+ path
		)
		return

	var ability := loaded_resource as UnitAbilityData
	var target_list := (
		_active_abilities
		if is_active
		else _passive_abilities
	)

	if target_list.has(ability):
		_set_status_error(
			"Эта способность уже добавлена юниту."
		)
		return

	target_list.append(ability)
	_refresh_ability_lists()


func _remove_selected_active_abilities() -> void:
	_remove_selected_abilities(
		active_ability_list,
		_active_abilities
	)


func _remove_selected_passive_abilities() -> void:
	_remove_selected_abilities(
		passive_ability_list,
		_passive_abilities
	)


func _remove_selected_abilities(
	item_list: ItemList,
	abilities: Array[UnitAbilityData]
) -> void:
	var selected_indices := item_list.get_selected_items()
	selected_indices.reverse()

	for ability_index in selected_indices:
		abilities.remove_at(ability_index)

	_refresh_ability_lists()


func _refresh_ability_lists() -> void:
	_fill_ability_list(
		active_ability_list,
		_active_abilities
	)
	_fill_ability_list(
		passive_ability_list,
		_passive_abilities
	)


func _fill_ability_list(
	item_list: ItemList,
	abilities: Array[UnitAbilityData]
) -> void:
	item_list.clear()

	for ability in abilities:
		var display_name := "(пустая ссылка)"
		var resource_path := ""

		if ability != null:
			display_name = ability.ability_name
			resource_path = ability.resource_path

			if display_name.strip_edges().is_empty():
				display_name = resource_path.get_file()

		item_list.add_item(display_name)

		if not resource_path.is_empty():
			item_list.set_item_tooltip(
				item_list.item_count - 1,
				resource_path
			)


# ============================================================
# ВИЗУАЛЬНЫЕ РЕСУРСЫ
# ============================================================

func _load_texture_into_slot(
	path: String,
	slot_name: String
) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if not (loaded_resource is Texture2D):
		_set_status_error(
			"Godot не распознал файл как Texture2D: " + path
		)
		return

	if slot_name == "portrait":
		_portrait = loaded_resource as Texture2D
	elif slot_name == "battlefield":
		_battlefield_texture = loaded_resource as Texture2D

	_refresh_visual_paths()
	_refresh_preview()


func _load_frames_into_slot(
	path: String,
	slot_name: String
) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if not (loaded_resource is SpriteFrames):
		_set_status_error(
			"Выбранный ресурс не является SpriteFrames: " + path
		)
		return

	var frames := loaded_resource as SpriteFrames

	match slot_name:
		"idle":
			_idle_frames = frames
		"move":
			_move_frames = frames
		"block":
			_block_frames = frames
		"hit":
			_hit_frames = frames
		"death":
			_death_frames = frames

	_refresh_visual_paths()
	_refresh_preview()


func _clear_visual_slot(slot_name: String) -> void:
	match slot_name:
		"portrait":
			_portrait = null
		"battlefield":
			_battlefield_texture = null
		"idle":
			_idle_frames = null
		"move":
			_move_frames = null
		"block":
			_block_frames = null
		"hit":
			_hit_frames = null
		"death":
			_death_frames = null

	_refresh_visual_paths()
	_refresh_preview()


func _reset_visual_references() -> void:
	_portrait = null
	_battlefield_texture = null
	_idle_frames = null
	_move_frames = null
	_block_frames = null
	_hit_frames = null
	_death_frames = null


func _refresh_visual_paths() -> void:
	portrait_path.text = _get_resource_display_path(_portrait)
	battlefield_path.text = _get_resource_display_path(
		_battlefield_texture
	)
	idle_frames_path.text = _get_resource_display_path(
		_idle_frames
	)
	move_frames_path.text = _get_resource_display_path(
		_move_frames
	)
	block_frames_path.text = _get_resource_display_path(
		_block_frames
	)
	hit_frames_path.text = _get_resource_display_path(
		_hit_frames
	)
	death_frames_path.text = _get_resource_display_path(
		_death_frames
	)


func _get_resource_display_path(resource: Resource) -> String:
	if resource == null:
		return "Не назначено"

	if resource.resource_path.is_empty():
		return "Встроенный ресурс"

	return resource.resource_path


# ============================================================
# ПРЕДПРОСМОТР
# ============================================================

func _on_preview_text_changed(_new_text: String) -> void:
	_refresh_preview()


func _on_preview_value_changed(_new_value: float) -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	if preview_unit == null:
		return

	preview_unit.show_preview(
		_build_unit_data(),
		Vector2(80, 80)
	)


# ============================================================
# РАЗМЕР И КЛЮЧЕВЫЕ СЛОВА
# ============================================================

func _select_size(size_value: int) -> void:
	for option_index in range(size_option.item_count):
		if int(size_option.get_item_metadata(option_index)) == size_value:
			size_option.select(option_index)
			return

	size_option.select(0)


func _get_selected_size() -> UnitData.UnitSize:
	var selected_index := size_option.selected

	if selected_index < 0:
		return UnitData.UnitSize.NORMAL

	return int(
		size_option.get_item_metadata(selected_index)
	) as UnitData.UnitSize


func _parse_keywords(source_text: String) -> Array[String]:
	var result: Array[String] = []
	var normalized_text := source_text.replace(
		"\n",
		","
	).replace(
		";",
		","
	)

	for part in normalized_text.split(",", false):
		var keyword := part.strip_edges()

		if keyword.is_empty() or result.has(keyword):
			continue

		result.append(keyword)

	return result


func _join_keywords(values: Array[String]) -> String:
	var packed_values := PackedStringArray()

	for value in values:
		packed_values.append(value)

	return ", ".join(packed_values)


# ============================================================
# СТАТУС И ОТЧЁТ
# ============================================================

func _refresh_current_path() -> void:
	if _current_resource_path.is_empty():
		current_path_label.text = (
			"Новый ресурс — ещё не сохранён"
		)
	else:
		current_path_label.text = _current_resource_path


func _show_validation_report(report: Dictionary) -> void:
	var errors := report["errors"] as PackedStringArray
	var warnings := report["warnings"] as PackedStringArray
	var lines := PackedStringArray()

	if errors.is_empty():
		lines.append(
			"[color=#8cff9b]Ошибок нет. Юнит можно сохранять.[/color]"
		)
	else:
		lines.append(
			"[color=#ff8a8a]Ошибки (%d):[/color]" % errors.size()
		)

		for error_message in errors:
			lines.append("• " + error_message)

	if not warnings.is_empty():
		lines.append("")
		lines.append(
			"[color=#ffd27a]Предупреждения (%d):[/color]"
			% warnings.size()
		)

		for warning_message in warnings:
			lines.append("• " + warning_message)

	_set_status_message("\n".join(lines))


func _set_status_error(message: String) -> void:
	_set_status_message(
		"[color=#ff8a8a]Ошибка:[/color] " + message
	)


func _set_status_message(message: String) -> void:
	status_output.text = message
