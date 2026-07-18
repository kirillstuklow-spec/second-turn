extends Node2D


@onready var battle_engine: BattleEngine = (
	get_node_or_null("BattleEngine") as BattleEngine
)

@onready var battlefield_view: BattlefieldView = (
	get_node_or_null("Battlefield") as BattlefieldView
)

@onready var battle_hud: Control = (
	get_node_or_null("UI/BattleHUD") as Control
)

# Временная панель остаётся, пока её функции
# не перенесены в AbilityGrid нового HUD.
@onready var legacy_ability_panel: AbilityPanel = (
	get_node_or_null("UI/AbilityPanel") as AbilityPanel
)


func _ready() -> void:
	if not _validate_composition():
		return

	if not battle_engine.initialize(
		battlefield_view,
		legacy_ability_panel
	):
		push_error(
			"BattleScene: BattleEngine initialization failed"
		)
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

	if legacy_ability_panel == null:
		push_error(
			"BattleScene: temporary AbilityPanel was not found "
			+ "at 'BattleScene/UI/AbilityPanel'."
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

	print(
		"BattleScene: BattleHUD intent signals connected"
	)

	return true


func _on_end_turn_requested() -> void:
	print("BattleScene: end turn intent received")
	battle_engine.request_end_turn()
