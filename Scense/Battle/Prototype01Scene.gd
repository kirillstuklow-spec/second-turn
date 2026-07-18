extends Control

class_name Prototype01Scene


# -----------------------
# Data-ресурсы прототипа
# -----------------------

@export var archer_data : UnitData

@export var defense_dummy_data : UnitData

@export var armor_dummy_data : UnitData

@export var longbow_shot : UnitAbilityData


# -----------------------
# Узлы сцены
# -----------------------

@onready var archer_square : ColorRect = $UnitsRow/ArcherSquare

@onready var defense_dummy_square : ColorRect = $UnitsRow/DefenseDummySquare

@onready var armor_dummy_square : ColorRect = $UnitsRow/ArmorDummySquare

@onready var archer_label : Label = $UnitsRow/ArcherSquare/Label

@onready var defense_dummy_label : Label = $UnitsRow/DefenseDummySquare/Label

@onready var armor_dummy_label : Label = $UnitsRow/ArmorDummySquare/Label

@onready var ability_button : Button = $AbilityButton

@onready var ability_pipeline : AbilityPipeline = $AbilityPipeline


# -----------------------
# Runtime-состояние
# -----------------------

var archer_runtime : UnitRuntime

var defense_dummy_runtime : UnitRuntime

var armor_dummy_runtime : UnitRuntime

var active_unit : UnitRuntime

var pending_ability : UnitAbilityData

var is_targeting : bool = false


# -----------------------
# Цвета
# -----------------------

var archer_normal_color : Color

var defense_dummy_normal_color : Color

var armor_dummy_normal_color : Color

var target_highlight_color : Color = Color(1.0, 1.0, 0.3, 1.0)


func _ready() -> void:
	if not _validate_resources():
		return

	_save_normal_colors()
	_prepare_mouse_input()
	_create_runtime_units()
	_connect_ui()
	_refresh_labels()
	_clear_target_highlight()

	ability_button.text = longbow_shot.ability_name

	print("")
	print("Prototype 01 ready")
	print("Active unit: ", active_unit.data.unit_name)
	print("Press ability button, then click an enemy target")


# -----------------------
# Подготовка
# -----------------------

func _validate_resources() -> bool:
	var is_valid : bool = true

	if archer_data == null:
		push_error("Prototype01Scene: archer_data is not assigned")
		is_valid = false

	if defense_dummy_data == null:
		push_error("Prototype01Scene: defense_dummy_data is not assigned")
		is_valid = false

	if armor_dummy_data == null:
		push_error("Prototype01Scene: armor_dummy_data is not assigned")
		is_valid = false

	if longbow_shot == null:
		push_error("Prototype01Scene: longbow_shot is not assigned")
		is_valid = false

	if ability_pipeline == null:
		push_error("Prototype01Scene: AbilityPipeline node is missing or has no script")
		is_valid = false

	return is_valid


func _save_normal_colors() -> void:
	archer_normal_color = archer_square.color
	defense_dummy_normal_color = defense_dummy_square.color
	armor_dummy_normal_color = armor_dummy_square.color


func _prepare_mouse_input() -> void:
	archer_square.mouse_filter = Control.MOUSE_FILTER_IGNORE

	defense_dummy_square.mouse_filter = Control.MOUSE_FILTER_STOP
	armor_dummy_square.mouse_filter = Control.MOUSE_FILTER_STOP

	archer_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defense_dummy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	armor_dummy_label.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _create_runtime_units() -> void:
	archer_runtime = UnitRuntime.new()
	archer_runtime.setup(archer_data, 1)

	defense_dummy_runtime = UnitRuntime.new()
	defense_dummy_runtime.setup(defense_dummy_data, 2)

	armor_dummy_runtime = UnitRuntime.new()
	armor_dummy_runtime.setup(armor_dummy_data, 2)

	active_unit = archer_runtime


func _connect_ui() -> void:
	ability_button.pressed.connect(_on_ability_button_pressed)

	defense_dummy_square.gui_input.connect(_on_defense_dummy_square_gui_input)
	armor_dummy_square.gui_input.connect(_on_armor_dummy_square_gui_input)


# -----------------------
# UI
# -----------------------

func _on_ability_button_pressed() -> void:
	pending_ability = longbow_shot
	is_targeting = true

	_highlight_targets()

	print("")
	print("Ability selected: ", pending_ability.ability_name)
	print("Choose enemy target")


func _on_defense_dummy_square_gui_input(event : InputEvent) -> void:
	if _is_left_mouse_click(event):
		_try_select_target(defense_dummy_runtime)


func _on_armor_dummy_square_gui_input(event : InputEvent) -> void:
	if _is_left_mouse_click(event):
		_try_select_target(armor_dummy_runtime)


func _is_left_mouse_click(event : InputEvent) -> bool:
	return event is InputEventMouseButton \
		and event.button_index == MOUSE_BUTTON_LEFT \
		and event.pressed


func _try_select_target(target_unit : UnitRuntime) -> void:
	if not is_targeting:
		print("No ability selected")
		return

	if pending_ability == null:
		print("No pending ability")
		return

	if target_unit == null:
		print("Target is null")
		return

	if active_unit.team_id == target_unit.team_id:
		print("Cannot target ally")
		return

	ability_pipeline.execute_ability(active_unit, target_unit, pending_ability)

	pending_ability = null
	is_targeting = false

	_clear_target_highlight()
	_refresh_labels()


func _highlight_targets() -> void:
	defense_dummy_square.color = target_highlight_color
	armor_dummy_square.color = target_highlight_color


func _clear_target_highlight() -> void:
	archer_square.color = archer_normal_color
	defense_dummy_square.color = defense_dummy_normal_color
	armor_dummy_square.color = armor_dummy_normal_color


func _refresh_labels() -> void:
	archer_label.text = "Archer\nHP: " + str(archer_runtime.current_hp)
	defense_dummy_label.text = "Defense\nHP: " + str(defense_dummy_runtime.current_hp)
	armor_dummy_label.text = "Armor\nHP: " + str(armor_dummy_runtime.current_hp)
	
	
