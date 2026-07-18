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
		
	if defenses_value_label == null:
		push_error(
			"UnitInfoPanel: DefensesValueLabel was not found"
		)
		is_valid = false

	if immunities_value_label == null:
		push_error(
			"UnitInfoPanel: ImmunitiesValueLabel was not found"
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
@onready var defenses_value_label: Label = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/StatsSection/"
		+ "DefensesRow/DefensesValueLabel"
	) as Label
)

@onready var immunities_value_label: Label = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/StatsSection/"
		+ "ImmunitiesRow/ImmunitiesValueLabel"
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

func show_unit(
	unit: UnitRuntime,
	is_active: bool
) -> void:
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

	_set_action_controls(is_active)

	unit_name_label.text = unit.data.unit_name

	hp_value_label.text = "%d / %d" % [
		unit.current_hp,
		unit.data.max_hp
	]

	armor_value_label.text = str(unit.armor)

	defenses_value_label.text = _format_keywords(
		unit.active_defenses
	)

	immunities_value_label.text = _format_keywords(
		unit.active_immunities
	)
func _format_keywords(keywords: Variant) -> String:
	if keywords == null:
		return "—"

	if keywords.size() == 0:
		return "—"

	var keyword_texts: PackedStringArray = []

	for keyword in keywords:
		keyword_texts.append(str(keyword))

	return ", ".join(keyword_texts)

# ============================================================
# ДОСТУПНОСТЬ УПРАВЛЕНИЯ
# ============================================================

func _set_action_controls(is_active: bool) -> void:
	if end_turn_button == null:
		return

	end_turn_button.visible = is_active
	end_turn_button.disabled = not is_active
	
# ============================================================
# ОЧИСТКА ПАНЕЛИ
# ============================================================

func clear_unit() -> void:
	displayed_unit = null

	_set_action_controls(false)

	if unit_name_label != null:
		unit_name_label.text = ""

	if hp_value_label != null:
		hp_value_label.text = "— / —"

	if armor_value_label != null:
		armor_value_label.text = "—"

	if defenses_value_label != null:
		defenses_value_label.text = "—"

	if immunities_value_label != null:
		immunities_value_label.text = "—"
