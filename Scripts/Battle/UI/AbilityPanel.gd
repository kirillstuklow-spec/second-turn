extends Control

class_name AbilityPanel


signal ability_selected(unit_ability : UnitAbilityData)


var buttons_root : VBoxContainer = null


func _ready() -> void:
	_ensure_buttons_root()


# -----------------------
# Показ способностей активного юнита
# -----------------------

func show_unit_abilities(unit : UnitRuntime) -> void:
	_ensure_buttons_root()
	_clear_buttons()

	if unit == null:
		return

	if unit.data == null:
		return

	for unit_ability in unit.data.active_abilities:
		_create_ability_button(unit_ability)


# -----------------------
# Создание кнопок
# -----------------------

func _ensure_buttons_root() -> void:
	if buttons_root != null:
		return

	buttons_root = VBoxContainer.new()
	buttons_root.name = "AbilityButtons"

	add_child(buttons_root)


func _create_ability_button(unit_ability : UnitAbilityData) -> void:
	if unit_ability == null:
		return

	var button : Button = Button.new()

	button.text = unit_ability.ability_name
	button.custom_minimum_size = Vector2(180, 40)

	button.pressed.connect(_on_ability_button_pressed.bind(unit_ability))

	buttons_root.add_child(button)


func _clear_buttons() -> void:
	if buttons_root == null:
		return

	for child in buttons_root.get_children():
		child.queue_free()


# -----------------------
# Нажатие кнопки способности
# -----------------------

func _on_ability_button_pressed(unit_ability : UnitAbilityData) -> void:
	if unit_ability == null:
		return

	ability_selected.emit(unit_ability)
	
	
