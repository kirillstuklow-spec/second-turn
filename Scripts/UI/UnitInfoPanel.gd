extends Control

class_name UnitInfoPanel

signal end_turn_requested
# ============================================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================================

func _ready() -> void:
	if not _validate_nodes():
		return

	var pressed_callback := Callable(
		self,
		"_on_end_turn_button_pressed"
	)

	if not end_turn_button.pressed.is_connected(
		pressed_callback
	):
		end_turn_button.pressed.connect(
			pressed_callback
		)

	clear_unit()

	print("UnitInfoPanel: initialized")

# ============================================================
# НАМЕРЕНИЯ ПОЛЬЗОВАТЕЛЯ
# ============================================================

func _on_end_turn_button_pressed() -> void:
	print("UnitInfoPanel: end turn button pressed")
	end_turn_requested.emit()
	
	
# ============================================================
# ПРОВЕРКА УЗЛОВ
# ============================================================

func _validate_nodes() -> bool:
	var is_valid := true

	if unit_name_label == null:
		push_error(
			"UnitInfoPanel: UnitNameLabel was not found"
		)
		is_valid = false

	if hp_value_label == null:
		push_error(
			"UnitInfoPanel: HPValueLabel was not found"
		)
		is_valid = false

	if armor_value_label == null:
		push_error(
			"UnitInfoPanel: ArmorValueLabel was not found"
		)
		is_valid = false

	if end_turn_button == null:
		push_error(
			"UnitInfoPanel: EndTurnButton was not found"
		)
		is_valid = false

	return is_valid
	
# ============================================================
# УЗЛЫ ИНТЕРФЕЙСА
# ============================================================

@onready var unit_name_label: Label = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/StatsSection/UnitNameLabel"
	) as Label
)

@onready var hp_value_label: Label = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/StatsSection/"
		+ "CoreStatsGrid/HPValueLabel"
	) as Label
)

@onready var armor_value_label: Label = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/StatsSection/"
		+ "CoreStatsGrid/ArmorValueLabel"
	) as Label
)

@onready var end_turn_button: Button = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/"
		+ "PortraitSection/EndTurnButton"
	) as Button
)

# ============================================================
# ОТОБРАЖАЕМЫЙ ЮНИТ
# ============================================================

var displayed_unit: UnitRuntime = null


# ============================================================
# ОТОБРАЖЕНИЕ ЮНИТА
# ============================================================

func show_unit(unit: UnitRuntime) -> void:
	if unit == null:
		clear_unit()
		return

	if unit.data == null:
		push_error(
			"UnitInfoPanel: UnitRuntime has no UnitData"
		)
		clear_unit()
		return

	displayed_unit = unit

	unit_name_label.text = unit.data.unit_name

	hp_value_label.text = "%d / %d" % [
		unit.current_hp,
		unit.data.max_hp
	]

	armor_value_label.text = str(unit.armor)


func clear_unit() -> void:
	displayed_unit = null

	if unit_name_label != null:
		unit_name_label.text = ""

	if hp_value_label != null:
		hp_value_label.text = "— / —"

	if armor_value_label != null:
		armor_value_label.text = "—"
