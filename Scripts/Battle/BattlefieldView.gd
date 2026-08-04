extends Node2D

class_name BattlefieldView


signal cell_clicked(cell : CellRuntime)


const CELL_SIZE : Vector2 = Vector2(80, 80)
const UNIT_VIEW_SCENE: PackedScene = preload(
	"res://Scense/Unit/unit.tscn"
)


var cells_root : Node2D = null
var units_root : Node2D = null
var arena_background_root: Control = null

var _unit_views_by_id: Dictionary = {}


var is_targeting : bool = false

var active_unit : UnitRuntime = null

var targetable_cells : Array[CellRuntime] = []

func _ensure_cells_root() -> bool:
	if cells_root != null:
		return true

	cells_root = get_node_or_null("Cells") as Node2D

	if cells_root == null:
		push_error("BattlefieldView: child node 'Cells' not found. BattlefieldView.gd must be attached to Battlefield, and Battlefield must have direct child named Cells.")
		return false

	return true


func _ensure_units_root() -> bool:
	if units_root != null:
		return true

	units_root = get_node_or_null("Units") as Node2D

	if units_root == null:
		push_error(
			"BattlefieldView: child node 'Units' not found."
		)
		return false

	return true
	

# -----------------------
# Управление режимом выбора цели
# -----------------------

func set_targeting(
	value : bool,
	unit : UnitRuntime,
	new_targetable_cells : Array[CellRuntime] = []
) -> void:
	is_targeting = value
	active_unit = unit
	targetable_cells.clear()

	if value:
		targetable_cells.append_array(new_targetable_cells)


# -----------------------
# Отрисовка поля
# -----------------------

func draw_battlefield(battle_state : BattleState) -> void:
	if battle_state == null:
		push_error("BattlefieldView: battle_state is null")
		return

	if not _ensure_cells_root():
		return

	_sync_arena_background(battle_state)
	_clear_cells()

	for cell in battle_state.cells:
		_create_cell_view(cell)

	_sync_unit_views(battle_state)


# ============================================================
# ЗАДНИК АРЕНЫ
# ============================================================

func _sync_arena_background(
	battle_state: BattleState
) -> void:
	if (
		arena_background_root != null
		and is_instance_valid(arena_background_root)
	):
		arena_background_root.free()

	arena_background_root = null

	if battle_state.arena_data == null:
		return

	var arena_data := battle_state.arena_data
	var field_size := Vector2(
		battle_state.field_width * CELL_SIZE.x,
		battle_state.field_height * CELL_SIZE.y
	)

	arena_background_root = Control.new()
	arena_background_root.name = "ArenaBackground"
	arena_background_root.position = Vector2.ZERO
	arena_background_root.size = field_size
	arena_background_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_background_root.z_index = -100
	add_child(arena_background_root)

	var color_layer := ColorRect.new()
	color_layer.position = Vector2.ZERO
	color_layer.size = field_size
	color_layer.color = arena_data.background_color
	color_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_background_root.add_child(color_layer)

	if arena_data.background_texture == null:
		return

	var texture_layer := TextureRect.new()
	texture_layer.position = arena_data.background_offset
	texture_layer.size = field_size
	texture_layer.pivot_offset = field_size * 0.5
	texture_layer.scale = arena_data.background_scale
	texture_layer.texture = arena_data.background_texture
	texture_layer.modulate = arena_data.background_modulate
	texture_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_layer.stretch_mode = (
		TextureRect.STRETCH_KEEP_ASPECT_COVERED
	)
	texture_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_background_root.add_child(texture_layer)
		
func _clear_cells() -> void:
	if not _ensure_cells_root():
		return

	for child in cells_root.get_children():
		child.queue_free()
		
func _create_cell_view(cell : CellRuntime) -> void:
	if not _ensure_cells_root():
		return
	var cell_view := Control.new()

	cell_view.position = Vector2(
		cell.x * CELL_SIZE.x,
		cell.y * CELL_SIZE.y
	)

	cell_view.size = CELL_SIZE
	cell_view.mouse_filter = Control.MOUSE_FILTER_STOP

	cell_view.gui_input.connect(_on_cell_gui_input.bind(cell))

	if cell.visual_data == null:
		_add_fallback_background(
			cell_view,
			cell
		)
		_add_debug_label(
			cell_view,
			cell
		)
	else:
		_add_visual_background(
			cell_view,
			cell.visual_data
		)

	_add_interaction_overlay(
		cell_view,
		cell
	)

	cells_root.add_child(cell_view)


# ============================================================
# ВИЗУАЛЬНЫЙ СЛОЙ КЛЕТКИ
# ============================================================

func _add_visual_background(
	cell_view: Control,
	visual_data: CellVisualData
) -> void:
	_add_texture_layer(
		cell_view,
		visual_data.base_texture,
		visual_data
	)

	_add_texture_layer(
		cell_view,
		visual_data.decoration_texture,
		visual_data
	)


func _add_texture_layer(
	cell_view: Control,
	texture: Texture2D,
	visual_data: CellVisualData
) -> void:
	if texture == null:
		return

	var texture_rect := TextureRect.new()
	texture_rect.position = Vector2.ZERO
	texture_rect.size = CELL_SIZE
	texture_rect.texture = texture
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.stretch_mode = TextureRect.STRETCH_SCALE
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_rect.modulate = visual_data.modulate
	texture_rect.flip_h = visual_data.flip_h
	texture_rect.flip_v = visual_data.flip_v
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.pivot_offset = CELL_SIZE * 0.5
	texture_rect.rotation = deg_to_rad(
		float(visual_data.quarter_turns * 90)
	)

	cell_view.add_child(texture_rect)


func _add_fallback_background(
	cell_view: Control,
	cell: CellRuntime
) -> void:
	var background := ColorRect.new()
	background.position = Vector2.ZERO
	background.size = CELL_SIZE
	background.color = _get_color_for_zone(cell.zone)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_view.add_child(background)


func _add_interaction_overlay(
	cell_view: Control,
	cell: CellRuntime
) -> void:
	var overlay := ColorRect.new()
	overlay.position = Vector2.ZERO
	overlay.size = CELL_SIZE
	overlay.color = _get_cell_overlay_color(cell)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_view.add_child(overlay)


func _add_debug_label(
	cell_view: Control,
	cell: CellRuntime
) -> void:
	var label := Label.new()

	label.position = Vector2.ZERO
	label.size = CELL_SIZE
	label.text = _get_cell_label(cell)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_view.add_child(label)


# -----------------------
# Текст клетки
# -----------------------

func _get_cell_label(cell : CellRuntime) -> String:
	var text : String = str(cell.x) + "," + str(cell.y) + "\n" + _get_zone_label(cell.zone)

	return text


# -----------------------
# Представления юнитов
# -----------------------

func _sync_unit_views(battle_state: BattleState) -> void:
	if not _ensure_units_root():
		return

	var visible_unit_ids: Dictionary = {}

	for unit in battle_state.units:
		if unit == null:
			continue

		var unit_id : int = unit.get_instance_id()

		if not unit.is_alive or unit.cell == null:
			_remove_unit_view(unit_id, true)
			continue

		visible_unit_ids[unit_id] = true

		var unit_view := _get_or_create_unit_view(
			unit_id
		)

		if unit_view == null:
			continue

		var animate_movement := unit_view.displayed_unit != null

		unit_view.show_runtime(
			unit,
			CELL_SIZE,
			animate_movement
		)

	for stored_id in _unit_views_by_id.keys():
		if not visible_unit_ids.has(stored_id):
			_remove_unit_view(stored_id, false)


func _get_or_create_unit_view(
	unit_id: int
) -> UnitView:
	if _unit_views_by_id.has(unit_id):
		return _unit_views_by_id[unit_id] as UnitView

	var unit_view := UNIT_VIEW_SCENE.instantiate() as UnitView

	if unit_view == null:
		push_error(
			"BattlefieldView: UnitView scene could not be instantiated"
		)
		return null

	units_root.add_child(unit_view)
	_unit_views_by_id[unit_id] = unit_view

	return unit_view


func _remove_unit_view(
	unit_id: int,
	play_death: bool
) -> void:
	if not _unit_views_by_id.has(unit_id):
		return

	var unit_view := _unit_views_by_id[unit_id] as UnitView
	_unit_views_by_id.erase(unit_id)

	if unit_view == null or not is_instance_valid(unit_view):
		return

	if play_death:
		unit_view.play_death_and_remove()
	else:
		unit_view.queue_free()


# -----------------------
# Цвет клетки
# -----------------------

func _get_cell_overlay_color(
	cell: CellRuntime
) -> Color:
	if is_targeting and targetable_cells.has(cell):
		return Color(1.0, 1.0, 0.15, 0.46)

	return Color.TRANSPARENT


func _get_color_for_zone(zone: int) -> Color:
	if zone == CellRuntime.CellZone.PLAYER_1_DEPLOYMENT:
		return Color(0.2, 0.8, 0.2, 1.0)

	if zone == CellRuntime.CellZone.PLAYER_1_MAIN:
		return Color(0.45, 0.9, 0.45, 1.0)

	if zone == CellRuntime.CellZone.NEUTRAL:
		return Color(0.65, 0.65, 0.65, 1.0)

	if zone == CellRuntime.CellZone.PLAYER_2_MAIN:
		return Color(0.9, 0.45, 0.45, 1.0)

	if zone == CellRuntime.CellZone.PLAYER_2_DEPLOYMENT:
		return Color(0.8, 0.2, 0.2, 1.0)

	return Color(1.0, 1.0, 1.0, 1.0)


func _get_zone_label(zone: int) -> String:
	if zone == CellRuntime.CellZone.PLAYER_1_DEPLOYMENT:
		return "D1"

	if zone == CellRuntime.CellZone.PLAYER_1_MAIN:
		return "P1"

	if zone == CellRuntime.CellZone.NEUTRAL:
		return "N"

	if zone == CellRuntime.CellZone.PLAYER_2_MAIN:
		return "P2"

	if zone == CellRuntime.CellZone.PLAYER_2_DEPLOYMENT:
		return "D2"

	return "?"


# -----------------------
# Клик по клетке
# -----------------------

func _on_cell_gui_input(event : InputEvent, cell : CellRuntime) -> void:
	if not _is_left_mouse_click(event):
		return

	cell_clicked.emit(cell)


func _is_left_mouse_click(event : InputEvent) -> bool:
	return event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed


# -----------------------
# Проверка цели для подсветки
# -----------------------

func _is_enemy_occupied_cell(cell : CellRuntime) -> bool:
	if cell == null:
		return false

	if cell.occupying_unit == null:
		return false

	if active_unit == null:
		return false

	return cell.occupying_unit.team_id != active_unit.team_id
	
