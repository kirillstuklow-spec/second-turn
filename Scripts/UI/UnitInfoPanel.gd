extends Control


signal end_turn_requested


@onready var end_turn_button: Button = (
	get_node_or_null("%EndTurnButton") as Button
)


func _ready() -> void:
	if end_turn_button == null:
		push_error(
			"UnitInfoPanel: EndTurnButton was not found. "
			+ "Make sure the button is marked as a unique node."
		)
		return

	var pressed_callback := Callable(
		self,
		"_on_end_turn_button_pressed"
	)

	if not end_turn_button.pressed.is_connected(pressed_callback):
		end_turn_button.pressed.connect(pressed_callback)

	print("UnitInfoPanel: EndTurnButton connected")


func _on_end_turn_button_pressed() -> void:
	print("UnitInfoPanel: end turn button pressed")
	end_turn_requested.emit()
