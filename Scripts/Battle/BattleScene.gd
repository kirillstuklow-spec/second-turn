extends Node2D


@onready var battle_engine: Node = get_node_or_null("BattleEngine")
@onready var battlefield_view: Node = get_node_or_null("Battlefield")

@onready var battle_hud: Control = (
	get_node_or_null("UI/BattleHUD") as Control
)

# Временный миграционный мост.
# После создания публичного входа BattleEngine эта ссылка будет удалена.
@onready var legacy_end_turn_button: Button = (
	get_node_or_null("UI/EndTurnButton") as Button
)


func _ready() -> void:
	if not _validate_composition():
		return

	if not _connect_components():
		return

	print("BattleScene: composition root is ready")


func _validate_composition() -> bool:
	var composition_is_valid := true

	if battle_engine == null:
		push_error(
			"BattleScene: BattleEngine was not found at "
			+ "'BattleScene/BattleEngine'."
		)
		composition_is_valid = false

	if battlefield_view == null:
		push_error(
			"BattleScene: Battlefield was not found at "
			+ "'BattleScene/Battlefield'."
		)
		composition_is_valid = false

	if battle_hud == null:
		push_error(
			"BattleScene: BattleHUD was not found at "
			+ "'BattleScene/UI/BattleHUD'."
		)
		composition_is_valid = false

	if legacy_end_turn_button == null:
		push_error(
			"BattleScene: the temporary legacy EndTurnButton "
			+ "was not found at 'BattleScene/UI/EndTurnButton'."
		)
		composition_is_valid = false

	return composition_is_valid


func _connect_components() -> bool:
	if not battle_hud.has_signal("end_turn_requested"):
		push_error(
			"BattleScene: BattleHUD does not provide "
			+ "the 'end_turn_requested' signal."
		)
		return false

	var end_turn_callback := Callable(
		self,
		"_on_end_turn_requested"
	)

	if not battle_hud.is_connected(
		"end_turn_requested",
		end_turn_callback
	):
		battle_hud.connect(
			"end_turn_requested",
			end_turn_callback
		)

	print("BattleScene: BattleHUD intent signals connected")

	return true


func _on_end_turn_requested() -> void:
	print("BattleScene: end turn intent received")

	if legacy_end_turn_button == null:
		push_error(
			"BattleScene: cannot forward the end-turn intent "
			+ "because the legacy EndTurnButton is missing."
		)
		return

	print("BattleScene: forwarding intent to existing turn flow")

	# Испускаем тот же сигнал, который возникает при обычном
	# нажатии старой кнопки. Дальнейшую работу выполняет
	# уже существующая цепочка BattleEngine и TurnPipeline.
	legacy_end_turn_button.pressed.emit()
	
