extends Control

class_name ArenaBuilder


# ============================================================
# КОНСТАНТЫ
# ============================================================

const ARENA_WIDTH := 7
const ARENA_HEIGHT := 5
const GRID_CELL_SIZE := Vector2(72, 72)

const ARENA_DIRECTORY := "res://Resources/Arenas/Arenas"
const CREATED_ARENA_DIRECTORY := (
	"res://Resources/Arenas/Arenas/Created"
)
const CELL_VISUAL_DIRECTORY := (
	"res://Resources/Arenas/CellVisuals"
)
const BIOME_DIRECTORY := "res://Resources/Arenas/Biomes"

const ARENA_FILTER := "*.tres, *.res ; ArenaData resources"
const BIOME_FILTER := "*.tres, *.res ; BiomeVisualData resources"
const TEXTURE_FILTER := (
	"*.png, *.jpg, *.jpeg, *.webp, *.svg ; Image textures"
)

const ZONE_VALUES: Array[int] = [
	ArenaZonePlacementData.Zone.NONE,
	ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT,
	ArenaZonePlacementData.Zone.PLAYER_1_MAIN,
	ArenaZonePlacementData.Zone.NEUTRAL,
	ArenaZonePlacementData.Zone.PLAYER_2_MAIN,
	ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT
]

const ZONE_LABELS: Array[String] = [
	"Без зоны",
	"Расстановка игрока 1",
	"Своя зона игрока 1",
	"Нейтральная полоса",
	"Своя зона игрока 2",
	"Расстановка игрока 2"
]


enum BuilderMode {
	CELLS,
	ZONES,
	OBJECTS
}


enum FileRequest {
	NONE,
	OPEN_ARENA,
	SAVE_ARENA,
	BACKGROUND_TEXTURE,
	BIOME
}


# ============================================================
# ЭЛЕМЕНТЫ ИНТЕРФЕЙСА
# ============================================================

var new_button: Button = null
var open_button: Button = null
var validate_button: Button = null
var save_button: Button = null
var save_as_button: Button = null
var current_path_label: Label = null

var arena_id_edit: LineEdit = null
var arena_name_edit: LineEdit = null
var description_edit: TextEdit = null
var mode_option: OptionButton = null

var cell_panel: VBoxContainer = null
var zone_panel: VBoxContainer = null
var object_panel: VBoxContainer = null

var biome_path_edit: LineEdit = null
var choose_biome_button: Button = null
var clear_biome_button: Button = null
var fill_biome_button: Button = null

var background_path_edit: LineEdit = null
var choose_background_button: Button = null
var clear_background_button: Button = null
var background_color_picker: ColorPickerButton = null
var background_modulate_picker: ColorPickerButton = null
var background_scale_x: SpinBox = null
var background_scale_y: SpinBox = null
var background_offset_x: SpinBox = null
var background_offset_y: SpinBox = null

var cell_palette_option: OptionButton = null
var refresh_palette_button: Button = null
var fill_cells_button: Button = null
var clear_cells_button: Button = null

var zone_palette_option: OptionButton = null
var player_1_capacity_spin: SpinBox = null
var player_2_capacity_spin: SpinBox = null
var player_1_counter_label: Label = null
var player_2_counter_label: Label = null
var standard_zones_button: Button = null
var clear_zones_button: Button = null

var object_status_label: Label = null
var object_refresh_button: Button = null

var preview_background_color: ColorRect = null
var preview_background_texture: TextureRect = null
var grid_container: GridContainer = null
var status_output: RichTextLabel = null
var file_dialog: FileDialog = null


# ============================================================
# СОСТОЯНИЕ BUILDER
# ============================================================

var _current_resource_path: String = ""
var _file_request := FileRequest.NONE

var _biome: BiomeVisualData = null
var _background_texture: Texture2D = null
var _palette_visuals: Array[CellVisualData] = []

var _cell_visuals: Array[CellVisualData] = []
var _zones: Array[int] = []
var _object_placements: Array[ArenaObjectPlacementData] = []
var _grid_cells: Array[ArenaGridCell] = []


# ============================================================
# ЖИЗНЕННЫЙ ЦИКЛ
# ============================================================

func _ready() -> void:
	_build_interface()
	_connect_controls()
	_refresh_cell_palette()
	_start_new_arena()


# ============================================================
# ПОСТРОЕНИЕ ИНТЕРФЕЙСА
# ============================================================

func _build_interface() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var page_background := ColorRect.new()
	page_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	page_background.color = Color(0.055, 0.063, 0.082, 1.0)
	page_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(page_background)

	var page_margin := MarginContainer.new()
	page_margin.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	page_margin.add_theme_constant_override("margin_left", 16)
	page_margin.add_theme_constant_override("margin_top", 12)
	page_margin.add_theme_constant_override("margin_right", 16)
	page_margin.add_theme_constant_override("margin_bottom", 12)
	add_child(page_margin)

	var page_column := VBoxContainer.new()
	page_column.add_theme_constant_override("separation", 8)
	page_margin.add_child(page_column)

	var title_row := HBoxContainer.new()
	title_row.add_theme_constant_override("separation", 8)
	page_column.add_child(title_row)

	var title := Label.new()
	title.text = "Arena Builder — версия 0.6.6"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title_row.add_child(title)

	new_button = _make_button("Новая")
	open_button = _make_button("Открыть")
	validate_button = _make_button("Проверить")
	save_button = _make_button("Сохранить")
	save_as_button = _make_button("Сохранить как…")

	title_row.add_child(new_button)
	title_row.add_child(open_button)
	title_row.add_child(validate_button)
	title_row.add_child(save_button)
	title_row.add_child(save_as_button)

	current_path_label = Label.new()
	current_path_label.text = "Новый ресурс — ещё не сохранён"
	current_path_label.text_overrun_behavior = (
		TextServer.OVERRUN_TRIM_ELLIPSIS
	)
	current_path_label.add_theme_color_override(
		"font_color",
		Color(0.63, 0.68, 0.76, 1.0)
	)
	page_column.add_child(current_path_label)

	page_column.add_child(HSeparator.new())

	var workspace := HSplitContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	workspace.split_offset = 420
	page_column.add_child(workspace)

	var editor_scroll := ScrollContainer.new()
	editor_scroll.custom_minimum_size = Vector2(390, 0)
	editor_scroll.horizontal_scroll_mode = (
		ScrollContainer.SCROLL_MODE_DISABLED
	)
	workspace.add_child(editor_scroll)

	var editor_margin := MarginContainer.new()
	editor_margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_margin.add_theme_constant_override("margin_left", 8)
	editor_margin.add_theme_constant_override("margin_top", 8)
	editor_margin.add_theme_constant_override("margin_right", 14)
	editor_margin.add_theme_constant_override("margin_bottom", 14)
	editor_scroll.add_child(editor_margin)

	var editor_column := VBoxContainer.new()
	editor_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	editor_column.add_theme_constant_override("separation", 8)
	editor_margin.add_child(editor_column)

	_build_identity_controls(editor_column)
	editor_column.add_child(HSeparator.new())
	_build_mode_controls(editor_column)

	var preview_column := VBoxContainer.new()
	preview_column.custom_minimum_size = Vector2(540, 0)
	preview_column.add_theme_constant_override("separation", 8)
	workspace.add_child(preview_column)

	var preview_title := Label.new()
	preview_title.text = "Каркас арены 7×5"
	preview_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_title.add_theme_font_size_override("font_size", 18)
	preview_column.add_child(preview_title)

	var preview_center := CenterContainer.new()
	preview_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview_column.add_child(preview_center)

	var preview_frame := Control.new()
	preview_frame.custom_minimum_size = Vector2(
		ARENA_WIDTH * GRID_CELL_SIZE.x,
		ARENA_HEIGHT * GRID_CELL_SIZE.y
	)
	preview_frame.clip_contents = true
	preview_center.add_child(preview_frame)

	preview_background_color = ColorRect.new()
	preview_background_color.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	preview_background_color.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	preview_frame.add_child(preview_background_color)

	preview_background_texture = TextureRect.new()
	preview_background_texture.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	preview_background_texture.pivot_offset = Vector2(
		ARENA_WIDTH * GRID_CELL_SIZE.x,
		ARENA_HEIGHT * GRID_CELL_SIZE.y
	) * 0.5
	preview_background_texture.expand_mode = (
		TextureRect.EXPAND_IGNORE_SIZE
	)
	preview_background_texture.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	preview_background_texture.mouse_filter = (
		Control.MOUSE_FILTER_IGNORE
	)
	preview_frame.add_child(preview_background_texture)

	grid_container = GridContainer.new()
	grid_container.columns = ARENA_WIDTH
	grid_container.add_theme_constant_override("h_separation", 0)
	grid_container.add_theme_constant_override("v_separation", 0)
	grid_container.mouse_filter = Control.MOUSE_FILTER_PASS
	preview_frame.add_child(grid_container)
	_build_grid_cells()

	var preview_hint := Label.new()
	preview_hint.text = (
		"ЛКМ рисует выбранным элементом. "
		+ "ПКМ в режиме клеток берёт плитку, "
		+ "а в режиме зон очищает разметку."
	)
	preview_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	preview_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	preview_hint.add_theme_color_override(
		"font_color",
		Color(0.63, 0.68, 0.76, 1.0)
	)
	preview_column.add_child(preview_hint)

	status_output = RichTextLabel.new()
	status_output.custom_minimum_size = Vector2(0, 116)
	status_output.bbcode_enabled = true
	status_output.scroll_active = true
	page_column.add_child(status_output)

	file_dialog = FileDialog.new()
	file_dialog.title = "Выбрать ресурс"
	file_dialog.size = Vector2i(900, 620)
	file_dialog.ok_button_text = "Выбрать"
	file_dialog.access = FileDialog.ACCESS_RESOURCES
	add_child(file_dialog)


func _build_identity_controls(
	parent: VBoxContainer
) -> void:
	var title := _make_section_title("Описание арены")
	parent.add_child(title)

	var identity_grid := GridContainer.new()
	identity_grid.columns = 2
	identity_grid.add_theme_constant_override("h_separation", 10)
	identity_grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(identity_grid)

	identity_grid.add_child(_make_label("Технический ID *"))
	arena_id_edit = LineEdit.new()
	arena_id_edit.placeholder_text = "ruined_chapel"
	arena_id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_grid.add_child(arena_id_edit)

	identity_grid.add_child(_make_label("Название *"))
	arena_name_edit = LineEdit.new()
	arena_name_edit.placeholder_text = "Разрушенная часовня"
	arena_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	identity_grid.add_child(arena_name_edit)

	parent.add_child(_make_label("Описание"))
	description_edit = TextEdit.new()
	description_edit.custom_minimum_size = Vector2(0, 72)
	description_edit.placeholder_text = (
		"Назначение арены, атмосфера и особенности композиции."
	)
	description_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	parent.add_child(description_edit)


func _build_mode_controls(
	parent: VBoxContainer
) -> void:
	var mode_row := HBoxContainer.new()
	mode_row.add_theme_constant_override("separation", 8)
	parent.add_child(mode_row)

	mode_row.add_child(_make_label("Режим"))
	mode_option = OptionButton.new()
	mode_option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_option.add_item("Клетки и задник")
	mode_option.add_item("Зоны")
	mode_option.add_item("Объекты")
	mode_row.add_child(mode_option)

	cell_panel = VBoxContainer.new()
	cell_panel.add_theme_constant_override("separation", 7)
	parent.add_child(cell_panel)
	_build_cell_panel(cell_panel)

	zone_panel = VBoxContainer.new()
	zone_panel.add_theme_constant_override("separation", 7)
	parent.add_child(zone_panel)
	_build_zone_panel(zone_panel)

	object_panel = VBoxContainer.new()
	object_panel.add_theme_constant_override("separation", 7)
	parent.add_child(object_panel)
	_build_object_panel(object_panel)


func _build_cell_panel(
	parent: VBoxContainer
) -> void:
	parent.add_child(_make_section_title("Задник"))

	var background_hint := _make_hint(
		"Задник необязателен и лежит под сеткой. "
		+ "Прозрачные участки клеток будут показывать его."
	)
	parent.add_child(background_hint)

	var background_row := HBoxContainer.new()
	background_row.add_theme_constant_override("separation", 6)
	parent.add_child(background_row)

	background_path_edit = LineEdit.new()
	background_path_edit.editable = false
	background_path_edit.text = "Не назначено"
	background_path_edit.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	background_row.add_child(background_path_edit)

	choose_background_button = _make_button("Выбрать…")
	clear_background_button = _make_button("×")
	background_row.add_child(choose_background_button)
	background_row.add_child(clear_background_button)

	var background_grid := GridContainer.new()
	background_grid.columns = 2
	background_grid.add_theme_constant_override("h_separation", 10)
	background_grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(background_grid)

	background_grid.add_child(_make_label("Цвет подложки"))
	background_color_picker = ColorPickerButton.new()
	background_color_picker.color = Color(0.08, 0.08, 0.1, 1.0)
	background_grid.add_child(background_color_picker)

	background_grid.add_child(_make_label("Оттенок изображения"))
	background_modulate_picker = ColorPickerButton.new()
	background_modulate_picker.color = Color.WHITE
	background_grid.add_child(background_modulate_picker)

	background_grid.add_child(_make_label("Масштаб X"))
	background_scale_x = _make_spin_box(0.1, 4.0, 0.05, 1.0)
	background_grid.add_child(background_scale_x)

	background_grid.add_child(_make_label("Масштаб Y"))
	background_scale_y = _make_spin_box(0.1, 4.0, 0.05, 1.0)
	background_grid.add_child(background_scale_y)

	background_grid.add_child(_make_label("Смещение X"))
	background_offset_x = _make_spin_box(
		-1000.0,
		1000.0,
		1.0,
		0.0
	)
	background_grid.add_child(background_offset_x)

	background_grid.add_child(_make_label("Смещение Y"))
	background_offset_y = _make_spin_box(
		-1000.0,
		1000.0,
		1.0,
		0.0
	)
	background_grid.add_child(background_offset_y)

	parent.add_child(HSeparator.new())
	parent.add_child(_make_section_title("Каркас из клеток"))

	var biome_row := HBoxContainer.new()
	biome_row.add_theme_constant_override("separation", 6)
	parent.add_child(biome_row)

	biome_path_edit = LineEdit.new()
	biome_path_edit.editable = false
	biome_path_edit.text = "Биом не назначен"
	biome_path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	biome_row.add_child(biome_path_edit)

	choose_biome_button = _make_button("Биом…")
	clear_biome_button = _make_button("×")
	biome_row.add_child(choose_biome_button)
	biome_row.add_child(clear_biome_button)

	fill_biome_button = _make_button(
		"Заполнить стандартной клеткой биома"
	)
	parent.add_child(fill_biome_button)

	parent.add_child(_make_label("Плитка для рисования"))
	var palette_row := HBoxContainer.new()
	palette_row.add_theme_constant_override("separation", 6)
	parent.add_child(palette_row)

	cell_palette_option = OptionButton.new()
	cell_palette_option.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)
	palette_row.add_child(cell_palette_option)

	refresh_palette_button = _make_button("Обновить")
	palette_row.add_child(refresh_palette_button)

	var cell_actions := HBoxContainer.new()
	cell_actions.add_theme_constant_override("separation", 6)
	parent.add_child(cell_actions)

	fill_cells_button = _make_button("Заполнить всё")
	clear_cells_button = _make_button("Очистить каркас")
	cell_actions.add_child(fill_cells_button)
	cell_actions.add_child(clear_cells_button)


func _build_zone_panel(
	parent: VBoxContainer
) -> void:
	parent.add_child(_make_section_title("Логические зоны"))
	parent.add_child(
		_make_hint(
			"Визуал клетки и зона независимы. "
			+ "Обязательны только две зоны расстановки."
		)
	)

	parent.add_child(_make_label("Зона для рисования"))
	zone_palette_option = OptionButton.new()

	for zone_label in ZONE_LABELS:
		zone_palette_option.add_item(zone_label)

	parent.add_child(zone_palette_option)

	var capacity_grid := GridContainer.new()
	capacity_grid.columns = 2
	capacity_grid.add_theme_constant_override("h_separation", 10)
	capacity_grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(capacity_grid)

	capacity_grid.add_child(_make_label("Вместимость игрока 1"))
	player_1_capacity_spin = _make_spin_box(1, 6, 1, 6)
	capacity_grid.add_child(player_1_capacity_spin)

	capacity_grid.add_child(_make_label("Вместимость игрока 2"))
	player_2_capacity_spin = _make_spin_box(1, 6, 1, 6)
	capacity_grid.add_child(player_2_capacity_spin)

	player_1_counter_label = Label.new()
	player_2_counter_label = Label.new()
	parent.add_child(player_1_counter_label)
	parent.add_child(player_2_counter_label)

	var zone_actions := HBoxContainer.new()
	zone_actions.add_theme_constant_override("separation", 6)
	parent.add_child(zone_actions)

	standard_zones_button = _make_button(
		"Стандартные 6 + 6"
	)
	clear_zones_button = _make_button("Очистить зоны")
	zone_actions.add_child(standard_zones_button)
	zone_actions.add_child(clear_zones_button)


func _build_object_panel(
	parent: VBoxContainer
) -> void:
	parent.add_child(_make_section_title("Объекты арены"))
	parent.add_child(
		_make_hint(
			"Режим уже зарезервирован в ArenaData и Builder. "
			+ "Палитра появится после создания ArenaObjectData."
		)
	)

	object_status_label = Label.new()
	object_status_label.text = (
		"Доступных типов объектов: 0\n"
		+ "Размещений на арене: 0"
	)
	parent.add_child(object_status_label)

	object_refresh_button = _make_button(
		"Обновить палитру объектов"
	)
	object_refresh_button.disabled = true
	parent.add_child(object_refresh_button)


func _build_grid_cells() -> void:
	_grid_cells.clear()

	for y in range(ARENA_HEIGHT):
		for x in range(ARENA_WIDTH):
			var grid_cell := ArenaGridCell.new()
			grid_cell.setup(x, y)
			grid_cell.cell_interacted.connect(
				_on_grid_cell_interacted
			)
			grid_container.add_child(grid_cell)
			_grid_cells.append(grid_cell)


func _make_button(text_value: String) -> Button:
	var button := Button.new()
	button.text = text_value
	return button


func _make_label(text_value: String) -> Label:
	var label := Label.new()
	label.text = text_value
	return label


func _make_section_title(text_value: String) -> Label:
	var label := _make_label(text_value)
	label.add_theme_font_size_override("font_size", 18)
	return label


func _make_hint(text_value: String) -> Label:
	var label := _make_label(text_value)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_color_override(
		"font_color",
		Color(0.63, 0.68, 0.76, 1.0)
	)
	return label


func _make_spin_box(
	minimum: float,
	maximum: float,
	step_value: float,
	default_value: float
) -> SpinBox:
	var spin_box := SpinBox.new()
	spin_box.min_value = minimum
	spin_box.max_value = maximum
	spin_box.step = step_value
	spin_box.value = default_value
	spin_box.allow_greater = false
	spin_box.allow_lesser = false
	spin_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return spin_box


# ============================================================
# СОЕДИНЕНИЕ СИГНАЛОВ
# ============================================================

func _connect_controls() -> void:
	new_button.pressed.connect(_start_new_arena)
	open_button.pressed.connect(_request_open)
	validate_button.pressed.connect(_validate_form)
	save_button.pressed.connect(_request_save)
	save_as_button.pressed.connect(_request_save.bind(true))

	mode_option.item_selected.connect(_on_mode_selected)

	choose_background_button.pressed.connect(
		_open_file_request.bind(FileRequest.BACKGROUND_TEXTURE)
	)
	clear_background_button.pressed.connect(
		_clear_background_texture
	)
	choose_biome_button.pressed.connect(
		_open_file_request.bind(FileRequest.BIOME)
	)
	clear_biome_button.pressed.connect(_clear_biome)
	fill_biome_button.pressed.connect(_fill_from_biome)

	refresh_palette_button.pressed.connect(_refresh_cell_palette)
	fill_cells_button.pressed.connect(_fill_all_cells)
	clear_cells_button.pressed.connect(_clear_visual_cells)

	player_1_capacity_spin.value_changed.connect(
		_on_capacity_changed
	)
	player_2_capacity_spin.value_changed.connect(
		_on_capacity_changed
	)
	standard_zones_button.pressed.connect(
		_apply_standard_deployment_zones
	)
	clear_zones_button.pressed.connect(_clear_zones)

	background_color_picker.color_changed.connect(
		_on_background_changed
	)
	background_modulate_picker.color_changed.connect(
		_on_background_changed
	)
	background_scale_x.value_changed.connect(
		_on_background_number_changed
	)
	background_scale_y.value_changed.connect(
		_on_background_number_changed
	)
	background_offset_x.value_changed.connect(
		_on_background_number_changed
	)
	background_offset_y.value_changed.connect(
		_on_background_number_changed
	)

	file_dialog.file_selected.connect(_on_file_selected)


# ============================================================
# НОВАЯ И ОТКРЫТАЯ АРЕНА
# ============================================================

func _start_new_arena() -> void:
	_current_resource_path = ""
	_biome = null
	_background_texture = null
	_object_placements.clear()

	_cell_visuals.clear()
	_cell_visuals.resize(ARENA_WIDTH * ARENA_HEIGHT)

	_zones.clear()

	for index in range(ARENA_WIDTH * ARENA_HEIGHT):
		_zones.append(ArenaZonePlacementData.Zone.NONE)

	arena_id_edit.text = ""
	arena_name_edit.text = ""
	description_edit.text = ""

	background_color_picker.color = Color(
		0.08,
		0.08,
		0.1,
		1.0
	)
	background_modulate_picker.color = Color.WHITE
	background_scale_x.value = 1.0
	background_scale_y.value = 1.0
	background_offset_x.value = 0.0
	background_offset_y.value = 0.0
	player_1_capacity_spin.value = 6
	player_2_capacity_spin.value = 6

	mode_option.select(BuilderMode.CELLS)
	_set_mode(BuilderMode.CELLS)
	_refresh_all()
	_set_status_message(
		"[color=#8fd3ff]Новая арена 7×5. "
		+ "Заполни 35 клеток и обе зоны расстановки.[/color]"
	)


func _request_open() -> void:
	_open_file_request(FileRequest.OPEN_ARENA)


func _load_arena_from_path(path: String) -> void:
	var loaded_resource := ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	if not loaded_resource is ArenaData:
		_set_status_error(
			"Выбранный ресурс не является ArenaData: " + path
		)
		return

	var arena_data := loaded_resource as ArenaData

	if (
		arena_data.width != ARENA_WIDTH
		or arena_data.height != ARENA_HEIGHT
	):
		_set_status_error(
			"ArenaBuilder 0.6.6 открывает только арены 7×5."
		)
		return

	_current_resource_path = path
	arena_id_edit.text = arena_data.arena_id
	arena_name_edit.text = arena_data.arena_name
	description_edit.text = arena_data.description

	_biome = arena_data.biome
	_background_texture = arena_data.background_texture
	background_color_picker.color = arena_data.background_color
	background_modulate_picker.color = (
		arena_data.background_modulate
	)
	background_scale_x.value = arena_data.background_scale.x
	background_scale_y.value = arena_data.background_scale.y
	background_offset_x.value = arena_data.background_offset.x
	background_offset_y.value = arena_data.background_offset.y
	player_1_capacity_spin.value = (
		arena_data.player_1_deployment_capacity
	)
	player_2_capacity_spin.value = (
		arena_data.player_2_deployment_capacity
	)

	_cell_visuals.clear()
	_zones.clear()

	for y in range(ARENA_HEIGHT):
		for x in range(ARENA_WIDTH):
			_cell_visuals.append(
				arena_data.get_cell_visual_at(x, y)
			)
			_zones.append(arena_data.get_zone_at(x, y))

	_object_placements.clear()

	for placement in arena_data.object_placements:
		if placement != null:
			_object_placements.append(
				placement.duplicate(true)
				as ArenaObjectPlacementData
			)

	_refresh_all()
	_set_status_message(
		"[color=#8fd3ff]Открыта арена:[/color] " + path
	)


# ============================================================
# СБОРКА ARENA DATA
# ============================================================

func _build_arena_data() -> ArenaData:
	var arena_data := ArenaData.new()
	arena_data.arena_id = arena_id_edit.text.strip_edges()
	arena_data.arena_name = arena_name_edit.text.strip_edges()
	arena_data.description = description_edit.text.strip_edges()
	arena_data.width = ARENA_WIDTH
	arena_data.height = ARENA_HEIGHT
	arena_data.biome = _biome
	arena_data.default_cell_visual = null
	arena_data.background_color = background_color_picker.color
	arena_data.background_texture = _background_texture
	arena_data.background_modulate = (
		background_modulate_picker.color
	)
	arena_data.background_scale = Vector2(
		float(background_scale_x.value),
		float(background_scale_y.value)
	)
	arena_data.background_offset = Vector2(
		float(background_offset_x.value),
		float(background_offset_y.value)
	)
	arena_data.default_zone = ArenaZonePlacementData.Zone.NONE
	arena_data.player_1_deployment_capacity = int(
		player_1_capacity_spin.value
	)
	arena_data.player_2_deployment_capacity = int(
		player_2_capacity_spin.value
	)

	for y in range(ARENA_HEIGHT):
		for x in range(ARENA_WIDTH):
			var index := _cell_index(x, y)
			var visual_placement := (
				ArenaCellVisualPlacementData.new()
			)
			visual_placement.x = x
			visual_placement.y = y
			visual_placement.cell_visual = _cell_visuals[index]
			arena_data.visual_placements.append(
				visual_placement
			)

			if _zones[index] == ArenaZonePlacementData.Zone.NONE:
				continue

			var zone_placement := ArenaZonePlacementData.new()
			zone_placement.x = x
			zone_placement.y = y
			zone_placement.zone = _zones[index]
			arena_data.zone_placements.append(zone_placement)

	for object_placement in _object_placements:
		if object_placement != null:
			arena_data.object_placements.append(
				object_placement.duplicate(true)
				as ArenaObjectPlacementData
			)

	arena_data.resource_name = arena_data.arena_name
	return arena_data


# ============================================================
# РЕЖИМЫ И РИСОВАНИЕ
# ============================================================

func _on_mode_selected(index: int) -> void:
	_set_mode(index)


func _set_mode(mode: int) -> void:
	cell_panel.visible = mode == BuilderMode.CELLS
	zone_panel.visible = mode == BuilderMode.ZONES
	object_panel.visible = mode == BuilderMode.OBJECTS


func _on_grid_cell_interacted(
	x: int,
	y: int,
	mouse_button: int
) -> void:
	var index := _cell_index(x, y)
	var mode := mode_option.selected

	if mode == BuilderMode.CELLS:
		if mouse_button == MOUSE_BUTTON_RIGHT:
			_pick_cell_visual(_cell_visuals[index])
			return

		var selected_visual := _get_selected_cell_visual()

		if selected_visual == null:
			_set_status_error(
				"В палитре не выбрана визуальная клетка."
			)
			return

		_cell_visuals[index] = selected_visual
		_refresh_grid_cell(index)
		return

	if mode == BuilderMode.ZONES:
		if mouse_button == MOUSE_BUTTON_RIGHT:
			_zones[index] = ArenaZonePlacementData.Zone.NONE
		else:
			var palette_index := zone_palette_option.selected

			if (
				palette_index < 0
				or palette_index >= ZONE_VALUES.size()
			):
				return

			_zones[index] = ZONE_VALUES[palette_index]

		_refresh_grid_cell(index)
		_refresh_deployment_counters()
		return

	_set_status_message(
		"[color=#ffd27a]Объекты арены пока не созданы. "
		+ "Режим зарезервирован и будет заполнен позднее.[/color]"
	)


func _fill_all_cells() -> void:
	var selected_visual := _get_selected_cell_visual()

	if selected_visual == null:
		_set_status_error(
			"Сначала выбери CellVisualData в палитре."
		)
		return

	for index in range(_cell_visuals.size()):
		_cell_visuals[index] = selected_visual

	_refresh_grid()


func _fill_from_biome() -> void:
	if _biome == null or _biome.default_cell_visual == null:
		_set_status_error(
			"У выбранного биома нет стандартной клетки."
		)
		return

	for index in range(_cell_visuals.size()):
		_cell_visuals[index] = _biome.default_cell_visual

	_pick_cell_visual(_biome.default_cell_visual)
	_refresh_grid()


func _clear_visual_cells() -> void:
	for index in range(_cell_visuals.size()):
		_cell_visuals[index] = null

	_refresh_grid()


func _apply_standard_deployment_zones() -> void:
	_clear_zones(false)
	player_1_capacity_spin.value = 6
	player_2_capacity_spin.value = 6

	for y in range(1, 4):
		for x in range(0, 2):
			_zones[_cell_index(x, y)] = (
				ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
			)

		for x in range(5, 7):
			_zones[_cell_index(x, y)] = (
				ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT
			)

	_refresh_grid()
	_refresh_deployment_counters()


func _clear_zones(refresh: bool = true) -> void:
	for index in range(_zones.size()):
		_zones[index] = ArenaZonePlacementData.Zone.NONE

	if refresh:
		_refresh_grid()
		_refresh_deployment_counters()


# ============================================================
# ПАЛИТРА КЛЕТОК
# ============================================================

func _refresh_cell_palette() -> void:
	var resource_paths := PackedStringArray()
	_collect_resource_paths(
		CELL_VISUAL_DIRECTORY,
		resource_paths
	)
	resource_paths.sort()

	_palette_visuals.clear()
	cell_palette_option.clear()

	for resource_path in resource_paths:
		var loaded_resource := ResourceLoader.load(resource_path)

		if not loaded_resource is CellVisualData:
			continue

		var cell_visual := loaded_resource as CellVisualData
		_palette_visuals.append(cell_visual)

		var item_name := cell_visual.display_name

		if item_name.strip_edges().is_empty():
			item_name = cell_visual.cell_visual_id

		cell_palette_option.add_item(item_name)
		cell_palette_option.set_item_tooltip(
			cell_palette_option.item_count - 1,
			resource_path
		)

	if _palette_visuals.is_empty():
		cell_palette_option.add_item(
			"CellVisualData не найдены"
		)
		cell_palette_option.disabled = true
		fill_cells_button.disabled = true
	else:
		cell_palette_option.disabled = false
		fill_cells_button.disabled = false
		cell_palette_option.select(0)


func _get_selected_cell_visual() -> CellVisualData:
	if (
		_palette_visuals.is_empty()
		or cell_palette_option.selected < 0
		or cell_palette_option.selected >= _palette_visuals.size()
	):
		return null

	return _palette_visuals[cell_palette_option.selected]


func _pick_cell_visual(
	cell_visual: CellVisualData
) -> void:
	if cell_visual == null:
		return

	for index in range(_palette_visuals.size()):
		var palette_visual := _palette_visuals[index]

		if (
			palette_visual == cell_visual
			or (
				not palette_visual.resource_path.is_empty()
				and palette_visual.resource_path
				== cell_visual.resource_path
			)
			or (
				not palette_visual.cell_visual_id.is_empty()
				and palette_visual.cell_visual_id
				== cell_visual.cell_visual_id
			)
		):
			cell_palette_option.select(index)
			return


# ============================================================
# ЗАДНИК И БИОМ
# ============================================================

func _clear_background_texture() -> void:
	_background_texture = null
	_refresh_background_controls()


func _clear_biome() -> void:
	_biome = null
	_refresh_background_controls()


func _on_background_changed(_value: Color) -> void:
	_refresh_background_preview()


func _on_background_number_changed(_value: float) -> void:
	_refresh_background_preview()


func _on_capacity_changed(_value: float) -> void:
	_refresh_deployment_counters()


# ============================================================
# ВАЛИДАЦИЯ И СОХРАНЕНИЕ
# ============================================================

func _validate_form() -> void:
	var report := ArenaValidator.validate(
		_build_arena_data(),
		_current_resource_path
	)
	_show_validation_report(report)


func _request_save(save_as: bool = false) -> void:
	var arena_data := _build_arena_data()
	var report := ArenaValidator.validate(
		arena_data,
		_current_resource_path
	)

	if not bool(report["is_valid"]):
		_show_validation_report(report)
		return

	if not save_as and not _current_resource_path.is_empty():
		_save_arena_to_path(
			arena_data,
			_current_resource_path
		)
		return

	_open_file_request(FileRequest.SAVE_ARENA)


func _save_arena_to_path(
	arena_data: ArenaData,
	requested_path: String
) -> void:
	var save_path := requested_path

	if save_path.get_extension().to_lower() not in ["tres", "res"]:
		save_path += ".tres"

	if not save_path.begins_with(ARENA_DIRECTORY + "/"):
		_set_status_error(
			"Арены следует сохранять внутри "
			+ ARENA_DIRECTORY
			+ "."
		)
		return

	if (
		FileAccess.file_exists(save_path)
		and save_path != _current_resource_path
	):
		_set_status_error(
			"Файл уже существует. Открой его для изменения "
			+ "или выбери другое имя: "
			+ save_path
		)
		return

	var report := ArenaValidator.validate(
		arena_data,
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
			"Не удалось создать папку: "
			+ save_path.get_base_dir()
		)
		return

	var save_error := ResourceSaver.save(arena_data, save_path)

	if save_error != OK:
		_set_status_error(
			"Godot не смог сохранить ArenaData. Код ошибки: "
			+ str(save_error)
		)
		return

	_current_resource_path = save_path
	_refresh_current_path()

	var success_text := (
		"[color=#8cff9b]Арена сохранена:[/color] "
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
		FileRequest.OPEN_ARENA:
			file_dialog.title = "Открыть ArenaData"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([ARENA_FILTER])
			file_dialog.current_dir = ARENA_DIRECTORY
		FileRequest.SAVE_ARENA:
			file_dialog.title = "Сохранить ArenaData"
			file_dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
			file_dialog.filters = PackedStringArray([ARENA_FILTER])
			file_dialog.current_dir = CREATED_ARENA_DIRECTORY
			file_dialog.current_file = _suggested_file_name()
		FileRequest.BACKGROUND_TEXTURE:
			file_dialog.title = "Выбрать изображение задника"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([TEXTURE_FILTER])
			file_dialog.current_dir = "res://"
		FileRequest.BIOME:
			file_dialog.title = "Выбрать BiomeVisualData"
			file_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
			file_dialog.filters = PackedStringArray([BIOME_FILTER])
			file_dialog.current_dir = BIOME_DIRECTORY
		_:
			return

	file_dialog.popup_centered_ratio(0.82)


func _on_file_selected(path: String) -> void:
	match _file_request:
		FileRequest.OPEN_ARENA:
			_load_arena_from_path(path)
		FileRequest.SAVE_ARENA:
			_save_arena_to_path(_build_arena_data(), path)
		FileRequest.BACKGROUND_TEXTURE:
			_load_background_texture(path)
		FileRequest.BIOME:
			_load_biome(path)

	_file_request = FileRequest.NONE


func _load_background_texture(path: String) -> void:
	var loaded_resource := ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	if not loaded_resource is Texture2D:
		_set_status_error(
			"Выбранный ресурс не является Texture2D: " + path
		)
		return

	_background_texture = loaded_resource as Texture2D
	_refresh_background_controls()


func _load_biome(path: String) -> void:
	var loaded_resource := ResourceLoader.load(
		path,
		"",
		ResourceLoader.CACHE_MODE_REPLACE
	)

	if not loaded_resource is BiomeVisualData:
		_set_status_error(
			"Выбранный ресурс не является BiomeVisualData: " + path
		)
		return

	_biome = loaded_resource as BiomeVisualData
	_refresh_background_controls()


# ============================================================
# ОБНОВЛЕНИЕ ПРЕДПРОСМОТРА
# ============================================================

func _refresh_all() -> void:
	_refresh_current_path()
	_refresh_background_controls()
	_refresh_grid()
	_refresh_deployment_counters()
	_refresh_object_status()


func _refresh_grid() -> void:
	for index in range(_grid_cells.size()):
		_refresh_grid_cell(index)


func _refresh_grid_cell(index: int) -> void:
	if (
		index < 0
		or index >= _grid_cells.size()
		or index >= _cell_visuals.size()
		or index >= _zones.size()
	):
		return

	_grid_cells[index].set_cell_visual(_cell_visuals[index])
	_grid_cells[index].set_zone(_zones[index])


func _refresh_background_controls() -> void:
	if _background_texture == null:
		background_path_edit.text = "Не назначено"
	else:
		background_path_edit.text = (
			_background_texture.resource_path
		)

	if _biome == null:
		biome_path_edit.text = "Биом не назначен"
		fill_biome_button.disabled = true
	else:
		biome_path_edit.text = _biome.resource_path
		fill_biome_button.disabled = (
			_biome.default_cell_visual == null
		)

	_refresh_background_preview()


func _refresh_background_preview() -> void:
	preview_background_color.color = background_color_picker.color
	preview_background_texture.texture = _background_texture
	preview_background_texture.modulate = (
		background_modulate_picker.color
	)
	preview_background_texture.scale = Vector2(
		float(background_scale_x.value),
		float(background_scale_y.value)
	)
	preview_background_texture.position = Vector2(
		float(background_offset_x.value),
		float(background_offset_y.value)
	) * (GRID_CELL_SIZE.x / BattlefieldView.CELL_SIZE.x)


func _refresh_deployment_counters() -> void:
	var player_1_count := _count_zone(
		ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT
	)
	var player_2_count := _count_zone(
		ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT
	)
	var player_1_target := int(player_1_capacity_spin.value)
	var player_2_target := int(player_2_capacity_spin.value)

	player_1_counter_label.text = (
		"Расстановка игрока 1: %d / %d"
		% [player_1_count, player_1_target]
	)
	player_2_counter_label.text = (
		"Расстановка игрока 2: %d / %d"
		% [player_2_count, player_2_target]
	)

	var good_color := Color(0.55, 1.0, 0.62, 1.0)
	var bad_color := Color(1.0, 0.52, 0.42, 1.0)
	var player_1_color := bad_color
	var player_2_color := bad_color

	if player_1_count == player_1_target:
		player_1_color = good_color

	if player_2_count == player_2_target:
		player_2_color = good_color

	player_1_counter_label.add_theme_color_override(
		"font_color",
		player_1_color
	)
	player_2_counter_label.add_theme_color_override(
		"font_color",
		player_2_color
	)


func _refresh_object_status() -> void:
	object_status_label.text = (
		"Доступных типов объектов: 0\n"
		+ "Размещений на арене: %d"
		% _object_placements.size()
	)


func _refresh_current_path() -> void:
	if _current_resource_path.is_empty():
		current_path_label.text = (
			"Новый ресурс — ещё не сохранён"
		)
	else:
		current_path_label.text = _current_resource_path


# ============================================================
# ОТЧЁТЫ И ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
# ============================================================

func _show_validation_report(report: Dictionary) -> void:
	var errors := report["errors"] as PackedStringArray
	var warnings := report["warnings"] as PackedStringArray
	var text := ""

	if errors.is_empty():
		text += "[color=#8cff9b]Ошибок нет. Арена готова к сохранению.[/color]"
	else:
		text += "[color=#ff8678]Ошибки:[/color]"

		for error in errors:
			text += "\n• " + error

	if not warnings.is_empty():
		text += "\n\n[color=#ffd27a]Предупреждения:[/color]"

		for warning in warnings:
			text += "\n• " + warning

	_set_status_message(text)


func _set_status_error(message: String) -> void:
	_set_status_message(
		"[color=#ff8678]Ошибка:[/color] " + message
	)


func _set_status_message(message: String) -> void:
	status_output.text = message


func _count_zone(zone_value: int) -> int:
	var count := 0

	for stored_zone in _zones:
		if stored_zone == zone_value:
			count += 1

	return count


func _cell_index(x: int, y: int) -> int:
	return y * ARENA_WIDTH + x


func _suggested_file_name() -> String:
	var technical_id := arena_id_edit.text.strip_edges()

	if technical_id.is_empty():
		return "NewArena.tres"

	return technical_id.to_pascal_case() + ".tres"


func _collect_resource_paths(
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
