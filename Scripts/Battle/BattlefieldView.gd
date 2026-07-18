extends Node2D

class_name BattlefieldView


signal cell_clicked(cell : CellRuntime)


const CELL_SIZE : Vector2 = Vector2(80, 80)


var cells_root : Node2D = null


var is_targeting : bool = false

var active_unit : UnitRuntime = null

func _ensure_cells_root() -> bool:
	if cells_root != null:
		return true

	cells_root = get_node_or_null("Cells") as Node2D

	if cells_root == null:
		push_error("BattlefieldView: child node 'Cells' not found. BattlefieldView.gd must be attached to Battlefield, and Battlefield must have direct child named Cells.")
		return false

	return true
	

# -----------------------
# Управление режимом выбора цели
# -----------------------

func set_targeting(value : bool, unit : UnitRuntime) -> void:
	is_targeting = value
	active_unit = unit


# -----------------------
# Отрисовка поля
# -----------------------

func draw_battlefield(battle_state : BattleState) -> void:
	if battle_state == null:
		push_error("BattlefieldView: battle_state is null")
		return

	if not _ensure_cells_root():
		return

	_clear_cells()

	for cell in battle_state.cells:
		_create_cell_view(cell)
		
func _clear_cells() -> void:
	if not _ensure_cells_root():
		return

	for child in cells_root.get_children():
		child.queue_free()
		
func _create_cell_view(cell : CellRuntime) -> void:
	if not _ensure_cells_root():
		return
	var cell_view : ColorRect = ColorRect.new()

	cell_view.position = Vector2(
		cell.x * CELL_SIZE.x,
		cell.y * CELL_SIZE.y
	)

	cell_view.size = CELL_SIZE
	cell_view.color = _get_cell_color(cell)
	cell_view.mouse_filter = Control.MOUSE_FILTER_STOP

	cell_view.gui_input.connect(_on_cell_gui_input.bind(cell))

	var label : Label = Label.new()

	label.position = Vector2.ZERO
	label.size = CELL_SIZE
	label.text = _get_cell_label(cell)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE

	cell_view.add_child(label)
	cells_root.add_child(cell_view)


# -----------------------
# Текст клетки
# -----------------------

func _get_cell_label(cell : CellRuntime) -> String:
	var text : String = str(cell.x) + "," + str(cell.y) + "\n" + _get_zone_label(cell.zone)

	if cell.occupying_unit != null:
		text += "\n" + cell.occupying_unit.data.unit_name
		text += "\nHP: " + str(cell.occupying_unit.current_hp)

	return text


# -----------------------
# Цвет клетки
# -----------------------

func _get_cell_color(cell : CellRuntime) -> Color:
	if is_targeting and _is_enemy_occupied_cell(cell):
		return Color(1.0, 1.0, 0.3, 1.0)

	return _get_color_for_zone(cell.zone)


func _get_color_for_zone(zone : CellRuntime.CellZone) -> Color:
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


func _get_zone_label(zone : CellRuntime.CellZone) -> String:
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
	
