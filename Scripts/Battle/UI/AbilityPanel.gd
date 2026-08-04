extends Control

class_name AbilityPanel


signal ability_selected(ability_runtime : UnitAbilityRuntime)


var buttons_root : VBoxContainer = null


func _ready() -> void:
	_ensure_buttons_root()


# -----------------------
# Показ способностей активного юнита
# -----------------------

func show_unit_abilities(
	unit : UnitRuntime,
	availability_results : Array[AbilityAvailabilityResult] = []
) -> void:
	_ensure_buttons_root()
	_clear_buttons()

	if unit == null:
		return

	if unit.data == null:
		return

	for ability_runtime in unit.active_abilities:
		_create_ability_button(
			ability_runtime,
			_find_availability_result(
				ability_runtime,
				availability_results
			)
		)


# -----------------------
# Создание кнопок
# -----------------------

func _ensure_buttons_root() -> void:
	if buttons_root != null:
		return

	buttons_root = VBoxContainer.new()
	buttons_root.name = "AbilityButtons"

	add_child(buttons_root)


func _create_ability_button(
	ability_runtime : UnitAbilityRuntime,
	availability : AbilityAvailabilityResult
) -> void:
	if ability_runtime == null or ability_runtime.data == null:
		return

	var button : Button = Button.new()

	button.text = ability_runtime.data.ability_name
	button.custom_minimum_size = Vector2(180, 40)
	button.disabled = (
		availability == null
		or not availability.is_available
	)

	if availability != null:
		button.tooltip_text = availability.get_summary()

	button.pressed.connect(
		_on_ability_button_pressed.bind(
			ability_runtime
		)
	)

	buttons_root.add_child(button)


func _clear_buttons() -> void:
	if buttons_root == null:
		return

	for child in buttons_root.get_children():
		child.queue_free()


# -----------------------
# Нажатие кнопки способности
# -----------------------

func _on_ability_button_pressed(
	ability_runtime : UnitAbilityRuntime
) -> void:
	if ability_runtime == null:
		return

	ability_selected.emit(ability_runtime)


func _find_availability_result(
	ability_runtime : UnitAbilityRuntime,
	availability_results : Array[AbilityAvailabilityResult]
) -> AbilityAvailabilityResult:
	for result in availability_results:
		if (
			result != null
			and result.ability_runtime == ability_runtime
		):
			return result

	return null
	
	
