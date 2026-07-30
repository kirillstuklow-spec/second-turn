extends Control

class_name CellBuilder


# ============================================================
# КОНСТАНТЫ И РЕЖИМЫ FILE DIALOG
# ============================================================

const CELL_VISUAL_DIRECTORY := "res://Resources/Arenas/CellVisuals"
const CREATED_CELL_VISUAL_DIRECTORY := (
	"res://Resources/Arenas/CellVisuals/Created"
)

const CELL_VISUAL_FILTER := (
	"*.tres, *.res ; CellVisualData resources"
)
const TEXTURE_FILTER := (
	"*.png, *.jpg, *.jpeg, *.webp, *.svg ; Image textures"
)


enum FileRequest {
	NONE,
	OPEN_CELL_VISUAL,
	SAVE_CELL_VISUAL,
	BASE_TEXTURE,
	DECORATION_TEXTURE
}


# ============================================================
# ЭЛЕМЕНТЫ ИНТЕРФЕЙСА
# ============================================================

@onready var new_button: Button = %NewButton
@onready var open_button: Button = %OpenButton
@onready var validate_button: Button = %ValidateButton
@onready var save_button: Button = %SaveButton
@onready var save_as_button: Button = %SaveAsButton
@onready var current_path_label: Label = %CurrentPathLabel

@onready var cell_visual_id_edit: LineEdit = %CellVisualIdEdit
@onready var display_name_edit: LineEdit = %DisplayNameEdit
@onready var description_edit: TextEdit = %DescriptionEdit

@onready var base_texture_path: LineEdit = %BaseTexturePath
@onready var decoration_texture_path: LineEdit = %DecorationTexturePath
@onready var choose_base_button: Button = %ChooseBaseButton
@onready var clear_base_button: Button = %ClearBaseButton
@onready var choose_decoration_button: Button = %ChooseDecorationButton
@onready var clear_decoration_button: Button = %ClearDecorationButton

@onready var modulate_picker: ColorPickerButton = %ModulatePicker
@onready var rotation_option: OptionButton = %RotationOption
@onready var flip_h_check: CheckBox = %FlipHCheck
@onready var flip_v_check: CheckBox = %FlipVCheck

@onready var preview_background: ColorRect = %PreviewBackground
@onready var preview_base: TextureRect = %PreviewBase
@onready var preview_decoration: TextureRect = %PreviewDecoration
@onready var preview_caption: Label = %PreviewCaption

@onready var status_output: RichTextLabel = %StatusOutput
@onready var file_dialog: FileDialog = %FileDialog


# ============================================================
# СОСТОЯНИЕ BUILDER
# ============================================================

var _current_resource_path: String = ""
var _file_request := FileRequest.NONE

var _base_texture: Texture2D = null
var _decoration_texture: Texture2D = null


# ============================================================
# ЖИЗНЕННЫЙ ЦИКЛ
# ============================================================

func _ready() -> void:
	_setup_rotation_options()
	_connect_controls()
	_start_new_cell_visual()


func _setup_rotation_options() -> void:
	rotation_option.clear()
	rotation_option.add_item("0°")
	rotation_option.add_item("90°")
	rotation_option.add_item("180°")
	rotation_option.add_item("270°")


func _connect_controls() -> void:
	new_button.pressed.connect(_start_new_cell_visual)
	open_button.pressed.connect(_request_open)
	validate_button.pressed.connect(_validate_form)
	save_button.pressed.connect(_request_save)
	save_as_button.pressed.connect(_request_save.bind(true))

	choose_base_button.pressed.connect(
		_open_file_request.bind(FileRequest.BASE_TEXTURE)
	)
	clear_base_button.pressed.connect(
		_clear_texture_slot.bind("base")
	)
	choose_decoration_button.pressed.connect(
		_open_file_request.bind(FileRequest.DECORATION_TEXTURE)
	)
	clear_decoration_button.pressed.connect(
		_clear_texture_slot.bind("decoration")
	)

	display_name_edit.text_changed.connect(
		_on_preview_text_changed
	)
	modulate_picker.color_changed.connect(
		_on_preview_color_changed
	)
	rotation_option.item_selected.connect(
		_on_preview_option_changed
	)
	flip_h_check.toggled.connect(
		_on_preview_toggle_changed
	)
	flip_v_check.toggled.connect(
		_on_preview_toggle_changed
	)

	file_dialog.file_selected.connect(_on_file_selected)


# ============================================================
# НОВАЯ И ОТКРЫТАЯ КЛЕТКА
# ============================================================

func _start_new_cell_visual() -> void:
	_current_resource_path = ""
	_populate_form(CellVisualData.new())
	_set_status_message(
		"[color=#8fd3ff]Новая визуальная клетка. "
		+ "Назначь хотя бы одну текстуру и нажми «Проверить».[/color]"
	)


func _request_open() -> void:
	_open_file_request(FileRequest.OPEN_CELL_VISUAL)


func _load_cell_visual_from_path(path: String) -> void:
	var loaded_resource := ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	if not loaded_resource is CellVisualData:
		_set_status_error(
			"Выбранный ресурс не является CellVisualData: " + path
		)
		return

	_current_resource_path = path
	_populate_form(loaded_resource as CellVisualData)
	_set_status_message(
		"[color=#8fd3ff]Открыта визуальная клетка:[/color] "
		+ path
	)


func _populate_form(cell_visual: CellVisualData) -> void:
	cell_visual_id_edit.text = cell_visual.cell_visual_id
	display_name_edit.text = cell_visual.display_name
	description_edit.text = cell_visual.description

	_base_texture = cell_visual.base_texture
	_decoration_texture = cell_visual.decoration_texture

	modulate_picker.color = cell_visual.modulate
	rotation_option.select(
		clampi(cell_visual.quarter_turns, 0, 3)
	)
	flip_h_check.button_pressed = cell_visual.flip_h
	flip_v_check.button_pressed = cell_visual.flip_v

	_refresh_texture_paths()
	_refresh_current_path()
	_refresh_preview()


# ============================================================
# СБОРКА DATA ИЗ ФОРМЫ
# ============================================================

func _build_cell_visual_data() -> CellVisualData:
	var cell_visual := CellVisualData.new()

	cell_visual.cell_visual_id = (
		cell_visual_id_edit.text.strip_edges()
	)
	cell_visual.display_name = display_name_edit.text.strip_edges()
	cell_visual.description = description_edit.text.strip_edges()

	cell_visual.base_texture = _base_texture
	cell_visual.decoration_texture = _decoration_texture
	cell_visual.modulate = modulate_picker.color
	cell_visual.quarter_turns = maxi(rotation_option.selected, 0)
	cell_visual.flip_h = flip_h_check.button_pressed
	cell_visual.flip_v = flip_v_check.button_pressed
	cell_visual.resource_name = cell_visual.display_name

	return cell_visual


# ============================================================
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ============================================================

func _validate_form() -> void:
	var report := CellVisualValidator.validate(
		_build_cell_visual_data(),
		_current_resource_path
	)

	_show_validation_report(report)
	_refresh_preview()


func _request_save(save_as: bool = false) -> void:
	var cell_visual := _build_cell_visual_data()
	var report := CellVisualValidator.validate(
		cell_visual,
		_current_resource_path
	)

	if not bool(report["is_valid"]):
		_show_validation_report(report)
		return

	if not save_as and not _current_resource_path.is_empty():
		_save_cell_visual_to_path(
			cell_visual,
			_current_resource_path
		)
		return

	_open_file_request(FileRequest.SAVE_CELL_VISUAL)


func _save_cell_visual_to_path(
	cell_visual: CellVisualData,
	requested_path: String
) -> void:
	var save_path := requested_path

	if save_path.get_extension().to_lower() not in ["tres", "res"]:
		save_path += ".tres"

	if not save_path.begins_with(CELL_VISUAL_DIRECTORY + "/"):
		_set_status_error(
			"Визуальные клетки следует сохранять внутри "
			+ CELL_VISUAL_DIRECTORY
			+ "."
		)
		return

	var report := CellVisualValidator.validate(
		cell_visual,
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
		cell_visual,
		save_path
	)

	if save_error != OK:
		_set_status_error(
			"Godot не смог сохранить CellVisualData. Код ошибки: "
			+ str(save_error)
		)
		return

	_current_resource_path = save_path
	_refresh_current_path()

	var success_text := (
		"[color=#8cff9b]Визуальная клетка сохранена:[/color] "
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
		FileRequest.OPEN_CELL_VISUAL:
			file_dialog.title = "Открыть CellVisualData"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				CELL_VISUAL_FILTER
			])
			file_dialog.current_dir = CELL_VISUAL_DIRECTORY
		FileRequest.SAVE_CELL_VISUAL:
			file_dialog.title = "Сохранить CellVisualData"
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = PackedStringArray([
				CELL_VISUAL_FILTER
			])
			file_dialog.current_dir = (
				CREATED_CELL_VISUAL_DIRECTORY
			)
			file_dialog.current_file = _suggest_file_name()
		_:
			file_dialog.title = "Выбрать изображение клетки"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([
				TEXTURE_FILTER
			])
			file_dialog.current_dir = "res://"

	file_dialog.popup_centered_ratio(0.82)


func _on_file_selected(path: String) -> void:
	var request := _file_request
	_file_request = FileRequest.NONE

	match request:
		FileRequest.OPEN_CELL_VISUAL:
			_load_cell_visual_from_path(path)
		FileRequest.SAVE_CELL_VISUAL:
			_save_cell_visual_to_path(
				_build_cell_visual_data(),
				path
			)
		FileRequest.BASE_TEXTURE:
			_load_texture_into_slot(path, "base")
		FileRequest.DECORATION_TEXTURE:
			_load_texture_into_slot(path, "decoration")


func _suggest_file_name() -> String:
	var technical_id := cell_visual_id_edit.text.strip_edges()

	if technical_id.is_empty():
		return "new_cell_visual.tres"

	return technical_id + ".tres"


# ============================================================
# ТЕКСТУРЫ
# ============================================================

func _load_texture_into_slot(
	path: String,
	slot_name: String
) -> void:
	var loaded_resource := ResourceLoader.load(path)

	if not loaded_resource is Texture2D:
		_set_status_error(
			"Godot не распознал файл как Texture2D: " + path
		)
		return

	if slot_name == "base":
		_base_texture = loaded_resource as Texture2D
	elif slot_name == "decoration":
		_decoration_texture = loaded_resource as Texture2D

	_refresh_texture_paths()
	_refresh_preview()


func _clear_texture_slot(slot_name: String) -> void:
	if slot_name == "base":
		_base_texture = null
	elif slot_name == "decoration":
		_decoration_texture = null

	_refresh_texture_paths()
	_refresh_preview()


func _refresh_texture_paths() -> void:
	base_texture_path.text = _get_resource_display_path(
		_base_texture
	)
	decoration_texture_path.text = _get_resource_display_path(
		_decoration_texture
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


func _on_preview_color_changed(_new_color: Color) -> void:
	_refresh_preview()


func _on_preview_option_changed(_index: int) -> void:
	_refresh_preview()


func _on_preview_toggle_changed(_pressed: bool) -> void:
	_refresh_preview()


func _refresh_preview() -> void:
	if preview_base == null or preview_decoration == null:
		return

	var cell_visual := _build_cell_visual_data()

	_apply_texture_to_preview(
		preview_base,
		cell_visual.base_texture,
		cell_visual
	)
	_apply_texture_to_preview(
		preview_decoration,
		cell_visual.decoration_texture,
		cell_visual
	)

	preview_caption.text = cell_visual.display_name

	if preview_caption.text.is_empty():
		preview_caption.text = "Предпросмотр клетки"


func _apply_texture_to_preview(
	texture_rect: TextureRect,
	texture: Texture2D,
	cell_visual: CellVisualData
) -> void:
	texture_rect.texture = texture
	texture_rect.visible = texture != null
	texture_rect.modulate = cell_visual.modulate
	texture_rect.flip_h = cell_visual.flip_h
	texture_rect.flip_v = cell_visual.flip_v
	texture_rect.rotation = deg_to_rad(
		float(cell_visual.quarter_turns * 90)
	)


# ============================================================
# ТЕКУЩИЙ ПУТЬ И СТАТУС
# ============================================================

func _refresh_current_path() -> void:
	if _current_resource_path.is_empty():
		current_path_label.text = (
			"Новый ресурс — ещё не сохранён"
		)
		return

	current_path_label.text = _current_resource_path


func _show_validation_report(report: Dictionary) -> void:
	var errors := report["errors"] as PackedStringArray
	var warnings := report["warnings"] as PackedStringArray
	var message := ""

	if errors.is_empty():
		message = "[color=#8cff9b]Ошибок нет.[/color]"
	else:
		message = "[color=#ff8585]Ошибки:[/color]"

		for error_message in errors:
			message += "\n• " + error_message

	if not warnings.is_empty():
		message += "\n\n[color=#ffd27a]Предупреждения:[/color]"

		for warning in warnings:
			message += "\n• " + warning

	if errors.is_empty() and warnings.is_empty():
		message += "\nРесурс готов к сохранению."

	_set_status_message(message)


func _set_status_error(message: String) -> void:
	_set_status_message(
		"[color=#ff8585]Ошибка:[/color] " + message
	)


func _set_status_message(message: String) -> void:
	status_output.text = message
