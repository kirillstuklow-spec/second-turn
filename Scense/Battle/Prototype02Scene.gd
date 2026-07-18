extends Control

class_name Prototype02Scene


const CELL_SIZE : Vector2 = Vector2(80, 80)


# -----------------------
# Data-ресурсы
# -----------------------

@export var archer_data : UnitData

@export var defense_dummy_data : UnitData

@export var armor_dummy_data : UnitData

@export var longbow_shot : UnitAbilityData


# -----------------------
# Узлы сцены
# -----------------------

@onready var battlefield_grid : GridContainer = $BattlefieldGrid

@onready var ability_button : Button = $AbilityButton

@onready var ability_pipeline : AbilityPipeline = $AbilityPipeline


# -----------------------
# Runtime-состояние
# -----------------------

var battle_state : BattleState

var is_targeting : bool = false


func _ready() -> void:
	if not _validate_resources():
		return

	battle_state = BattleState.new()

	battle_state.generate_battlefield()
	battle_state.print_battlefield_zones()

	_spawn_test_units()
	_connect_ui()
	print("Manual emit test")
	ability_button.pressed.emit()
	_draw_battlefield()

	battle_state.print_units()

	print("")
	print("Prototype 02 ready")
	print("BattleState cells count: ", battle_state.cells.size())
	print("BattleState units count: ", battle_state.units.size())
	#ability_button.text = longbow_shot.ability_name

# -----------------------
# Проверка ресурсов
# -----------------------

func _validate_resources() -> bool:
	var is_valid : bool = true

	if archer_data == null:
		push_error("Prototype02Scene: archer_data is not assigned")
		is_valid = false

	if defense_dummy_data == null:
		push_error("Prototype02Scene: defense_dummy_data is not assigned")
		is_valid = false

	if armor_dummy_data == null:
		push_error("Prototype02Scene: armor_dummy_data is not assigned")
		is_valid = false
	if longbow_shot == null:
		push_error("Prototype02Scene: longbow_shot is not assigned")
		is_valid = false

	if ability_pipeline == null:
		push_error("Prototype02Scene: AbilityPipeline node is missing or has no script")
		is_valid = false
	return is_valid
# -----------------------
# Подключение UI
# -----------------------

func _connect_ui() -> void:
	var button_callable : Callable = Callable(self, "_on_ability_button_pressed")

	print("AbilityButton path: ", ability_button.get_path())
	print("AbilityButton text: ", ability_button.text)
	print("AbilityButton disabled: ", ability_button.disabled)
	print("AbilityButton mouse_filter: ", ability_button.mouse_filter)

	if not ability_button.pressed.is_connected(button_callable):
		ability_button.pressed.connect(button_callable)

	print("AbilityButton connected: ", ability_button.pressed.is_connected(button_callable))
	ability_button.button_down.connect(_on_ability_button_down)
func _on_ability_button_pressed() -> void:
	print(">>> ABILITY BUTTON PRESSED CALLBACK FIRED")
	print("Ability button pressed")

	battle_state.set_pending_ability(longbow_shot)
	is_targeting = true

	_draw_battlefield()

	print("")
	print("Ability selected: ", longbow_shot.ability_name)
	print("Choose enemy target on battlefield")

# -----------------------
# Спавн юнитов
# -----------------------

func _spawn_test_units() -> void:
	var archer : UnitRuntime = battle_state.spawn_unit(archer_data, 1, 0, 2)

	battle_state.spawn_unit(defense_dummy_data, 2, 6, 1)
	battle_state.spawn_unit(armor_dummy_data, 2, 6, 3)

	if archer != null:
		battle_state.set_active_unit(archer)


# -----------------------
# Отрисовка поля
# -----------------------

func _draw_battlefield() -> void:
	_clear_grid()

	for cell in battle_state.cells:
		var cell_view : ColorRect = ColorRect.new()

		cell_view.custom_minimum_size = CELL_SIZE
		cell_view.color = _get_cell_color(cell)
		cell_view.mouse_filter = Control.MOUSE_FILTER_STOP

		cell_view.gui_input.connect(_on_cell_gui_input.bind(cell))

		var label : Label = Label.new()
		label.text = _get_cell_label(cell)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE

		cell_view.add_child(label)
		battlefield_grid.add_child(cell_view)


func _clear_grid() -> void:
	for child in battlefield_grid.get_children():
		child.queue_free()
func _get_cell_color(cell : CellRuntime) -> Color:
	if is_targeting and _is_enemy_occupied_cell(cell):
		return Color(1.0, 1.0, 0.3, 1.0)

	return _get_color_for_zone(cell.zone)

func _get_cell_label(cell : CellRuntime) -> String:
	var text : String = str(cell.x) + "," + str(cell.y) + "\n" + _get_zone_label(cell.zone)

	if cell.occupying_unit != null:
		text += "\n" + cell.occupying_unit.data.unit_name
		text += "\nHP: " + str(cell.occupying_unit.current_hp)

	return text


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
# Выбор цели
# -----------------------

func _on_cell_gui_input(event : InputEvent, cell : CellRuntime) -> void:
	if not _is_left_mouse_click(event):
		return

	if not is_targeting:
		print("No ability selected")
		return

	if battle_state.pending_ability == null:
		print("No pending ability")
		return

	var target_unit : UnitRuntime = battle_state.get_unit_on_cell(cell)

	if target_unit == null:
		print("Clicked empty cell: ", cell.x, ",", cell.y)
		return

	if battle_state.active_unit == null:
		push_error("Prototype02Scene: active_unit is null")
		return

	if battle_state.active_unit.team_id == target_unit.team_id:
		print("Cannot target ally")
		return

	ability_pipeline.execute_ability(
		battle_state.active_unit,
		target_unit,
		battle_state.pending_ability
	)

	battle_state.clear_pending_ability()
	is_targeting = false

	_draw_battlefield()


func _is_left_mouse_click(event : InputEvent) -> bool:
	return event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed


func _is_enemy_occupied_cell(cell : CellRuntime) -> bool:
	if cell == null:
		return false

	if cell.occupying_unit == null:
		return false

	if battle_state.active_unit == null:
		return false

	return cell.occupying_unit.team_id != battle_state.active_unit.team_id
func _on_ability_button_down() -> void:
	print(">>> ABILITY BUTTON DOWN")
