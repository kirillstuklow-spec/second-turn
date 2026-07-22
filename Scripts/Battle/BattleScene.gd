extends Node2D


# ============================================================
# КОМПОНЕНТЫ БОЕВОЙ СЦЕНЫ
# ============================================================

@onready var battle_engine: BattleEngine = (
	get_node_or_null("BattleEngine") as BattleEngine
)

@onready var battlefield_view: BattlefieldView = (
	get_node_or_null("Battlefield") as BattlefieldView
)

@onready var battle_hud: BattleHUD = (
	get_node_or_null("UI/BattleHUD") as BattleHUD
)

# ============================================================
# ИНИЦИАЛИЗАЦИЯ КОМПОЗИЦИИ
# ============================================================

func _ready() -> void:
	if not _validate_composition():
		return

	if not _connect_components():
		return

	if not battle_engine.initialize(
		battlefield_view
	):
		push_error(
			"BattleScene: BattleEngine initialization failed"
		)
		return

	print("BattleScene: composition root is ready")

	print("BattleScene: composition root is ready")
	
# ============================================================
# ПРОВЕРКА КОМПОЗИЦИИ
# ============================================================

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

	return composition_is_valid

# ============================================================
# СОЕДИНЕНИЕ КОМПОНЕНТОВ
# ============================================================

func _connect_components() -> bool:
	if not battle_hud.has_signal(
		"end_turn_requested"
	):
		push_error(
			"BattleScene: BattleHUD does not provide "
			+ "the 'end_turn_requested' signal."
		)
		return false

	if not battle_hud.has_signal(
		"ability_selected"
	):
		push_error(
			"BattleScene: BattleHUD does not provide "
			+ "the 'ability_selected' signal."
		)
		return false

	var end_turn_callback := Callable(
		self,
		"_on_end_turn_requested"
	)

	if not battle_hud.end_turn_requested.is_connected(
		end_turn_callback
	):
		battle_hud.end_turn_requested.connect(
			end_turn_callback
		)

	var ability_callback := Callable(
		self,
		"_on_ability_selected"
	)

	if not battle_hud.ability_selected.is_connected(
		ability_callback
	):
		battle_hud.ability_selected.connect(
			ability_callback
		)

	var unit_presentation_callback := Callable(
		self,
		"_on_presentation_refresh_requested"
	)

	if not battle_engine.presentation_refresh_requested.is_connected(
		unit_presentation_callback
	):
		battle_engine.presentation_refresh_requested.connect(
			unit_presentation_callback
		)

	var turn_state_callback := Callable(
		self,
		"_on_turn_state_refresh_requested"
	)

	if not battle_engine.turn_state_refresh_requested.is_connected(
		turn_state_callback
	):
		battle_engine.turn_state_refresh_requested.connect(
			turn_state_callback
		)

	print(
		"BattleScene: engine and HUD signals connected"
	)

	return true
	
# ============================================================
# НАМЕРЕНИЕ ЗАВЕРШЕНИЯ ХОДА
# ============================================================

func _on_end_turn_requested() -> void:
	print(
		"BattleScene: end turn intent received"
	)

	battle_engine.request_end_turn()
	
	
# ============================================================
# ОБНОВЛЕНИЕ ПРЕДСТАВЛЕНИЯ
# ============================================================

func _on_presentation_refresh_requested(
	active_unit: UnitRuntime
) -> void:
	if active_unit == null:
		print(
			"BattleScene: presentation refresh "
			+ "without active unit"
		)

		battle_hud.show_unit(
			null,
			false
		)
		return

	if active_unit.data == null:
		push_error(
			"BattleScene: active UnitRuntime has no UnitData"
		)

		battle_hud.show_unit(
			null,
			false
		)
		return

	print(
		"BattleScene: refreshing HUD for ",
		active_unit.data.unit_name
	)

	battle_hud.show_unit(
		active_unit,
		true
	)
# ============================================================
# ОБНОВЛЕНИЕ СОСТОЯНИЯ ХОДОВ В HUD
# ============================================================

func _on_turn_state_refresh_requested(
	turn_state: TurnState
) -> void:
	if turn_state == null:
		push_error(
			"BattleScene: received null TurnState"
		)

		battle_hud.show_turn_state(
			null
		)

		return

	print(
		"BattleScene: refreshing initiative queue "
		+ "for round ",
		turn_state.round_number
	)

	battle_hud.show_turn_state(
		turn_state
	)
	
# ============================================================
# НАМЕРЕНИЕ ВЫБОРА СПОСОБНОСТИ
# ============================================================

func _on_ability_selected(
	unit_ability: UnitAbilityData
) -> void:
	if unit_ability == null:
		push_error(
			"BattleScene: selected ability is null"
		)
		return

	print(
		"BattleScene: ability selection intent received: ",
		unit_ability.ability_name
	)

	battle_engine.request_ability_selection(
		unit_ability
	)
