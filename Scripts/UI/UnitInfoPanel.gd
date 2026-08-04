extends Control

class_name UnitInfoPanel

# ============================================================
# СИГНАЛЫ
# ============================================================

signal end_turn_requested

signal ability_selected(
	ability_runtime: UnitAbilityRuntime
)

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

	if portrait_texture == null:
		push_error(
			"UnitInfoPanel: PortraitTexture was not found"
		)
		is_valid = false

	if end_turn_button == null:
		push_error(
			"UnitInfoPanel: EndTurnButton was not found"
		)
		is_valid = false

	if ability_grid == null:
		push_error(
			"UnitInfoPanel: AbilityGrid was not found"
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

@onready var portrait_texture: TextureRect = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/"
		+ "PortraitSection/PortraitTexture"
	) as TextureRect
)

@onready var ability_grid: GridContainer = (
	get_node_or_null(
		"UnitInfoMargin/UnitInfoRow/AbilityGrid"
	) as GridContainer
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
	is_active: bool,
	availability_results: Array[AbilityAvailabilityResult] = []
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

	_show_portrait(unit.data)

	_show_unit_abilities(
		unit,
		is_active,
		availability_results
	)


func _show_portrait(unit_data: UnitData) -> void:
	if portrait_texture == null:
		return

	portrait_texture.texture = null

	if unit_data == null or unit_data.visual_data == null:
		return

	portrait_texture.texture = unit_data.visual_data.portrait


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
# ОТОБРАЖЕНИЕ СПОСОБНОСТЕЙ
# ============================================================

func _show_unit_abilities(
	unit: UnitRuntime,
	is_active: bool,
	availability_results: Array[AbilityAvailabilityResult]
) -> void:
	_clear_ability_buttons()

	if ability_grid == null:
		return

	if unit == null:
		return

	if unit.data == null:
		return

	var abilities := unit.active_abilities

	var visible_ability_count: int = min(
		abilities.size(),
		6
	)

	for ability_index in range(
		visible_ability_count
	):
		var ability_runtime: UnitAbilityRuntime = (
			abilities[ability_index] as UnitAbilityRuntime
		)

		_create_ability_button(
			ability_runtime,
			is_active,
			_find_availability_result(
				ability_runtime,
				availability_results
			)
		)

	if abilities.size() > 6:
		push_warning(
			"UnitInfoPanel: unit has more than "
			+ "6 active abilities"
		)


func _create_ability_button(
	ability_runtime: UnitAbilityRuntime,
	is_active: bool,
	availability: AbilityAvailabilityResult
) -> void:
	if ability_runtime == null or ability_runtime.data == null:
		return

	var ability_button := Button.new()

	ability_button.text = (
		ability_runtime.data.ability_name
	)

	ability_button.custom_minimum_size = Vector2(
		110,
		44
	)

	ability_button.disabled = (
		not is_active
		or availability == null
		or not availability.is_available
	)

	if availability != null:
		ability_button.tooltip_text = availability.get_summary()
	else:
		ability_button.tooltip_text = (
			"Доступность способности не рассчитана."
		)

	ability_button.pressed.connect(
		_on_ability_button_pressed.bind(
			ability_runtime
		)
	)

	ability_grid.add_child(
		ability_button
	)


func _clear_ability_buttons() -> void:
	if ability_grid == null:
		return

	for child in ability_grid.get_children():
		ability_grid.remove_child(child)
		child.queue_free()


# ============================================================
# ВЫБОР СПОСОБНОСТИ
# ============================================================

func _on_ability_button_pressed(
	ability_runtime: UnitAbilityRuntime
) -> void:
	if ability_runtime == null or ability_runtime.data == null:
		return

	print(
		"UnitInfoPanel: ability pressed: ",
		ability_runtime.data.ability_name
	)

	ability_selected.emit(
		ability_runtime
	)


func _find_availability_result(
	ability_runtime: UnitAbilityRuntime,
	availability_results: Array[AbilityAvailabilityResult]
) -> AbilityAvailabilityResult:
	for result in availability_results:
		if (
			result != null
			and result.ability_runtime == ability_runtime
		):
			return result

	return null
	
# # ============================================================
# ОЧИСТКА ПАНЕЛИ
# ============================================================

func clear_unit() -> void:
	displayed_unit = null

	_set_action_controls(false)
	_clear_ability_buttons()

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

	if portrait_texture != null:
		portrait_texture.texture = null
