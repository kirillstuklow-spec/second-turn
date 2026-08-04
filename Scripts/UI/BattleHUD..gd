extends Control

class_name BattleHUD

# ============================================================
# СИГНАЛЫ
# ============================================================

signal end_turn_requested

signal ability_selected(
	ability_runtime: UnitAbilityRuntime
)

# ============================================================
# ДОЧЕРНИЕ ПАНЕЛИ
# ============================================================

@onready var unit_info_panel: UnitInfoPanel = (
	get_node_or_null(
		"%UnitInfoPanel"
	) as UnitInfoPanel
)

@onready var initiative_queue_panel: InitiativeQueuePanel = (
	get_node_or_null(
		"%InitiativeQueuePanel"
	) as InitiativeQueuePanel
)
# ============================================================
# ОБНОВЛЕНИЕ HUD
# ============================================================

func show_unit(
	unit: UnitRuntime,
	is_active: bool,
	availability_results: Array[AbilityAvailabilityResult] = []
) -> void:
	if unit_info_panel == null:
		push_error(
			"BattleHUD: UnitInfoPanel is missing"
		)
		return

	unit_info_panel.show_unit(
		unit,
		is_active,
		availability_results
	)
	
func _ready() -> void:
	if not _validate_hud():
		return

	if not _connect_panels():
		return

	print("BattleHUD: panels connected")
	
# ============================================================
# ОБНОВЛЕНИЕ ЛЕНТЫ ИНИЦИАТИВЫ
# ============================================================

func show_turn_state(
	turn_state: TurnState
) -> void:
	if initiative_queue_panel == null:
		push_error(
			"BattleHUD: InitiativeQueuePanel is missing"
		)
		return

	if turn_state == null:
		initiative_queue_panel.clear_panel()
		return

	initiative_queue_panel.show_turn_state(
		turn_state
	)
# ============================================================
# ПРОВЕРКА HUD
# ============================================================

func _validate_hud() -> bool:
	if unit_info_panel == null:
		push_error(
			"BattleHUD: UnitInfoPanel was not found. "
			+ "Make sure the panel instance is marked "
			+ "as a unique node."
		)
		return false

	if initiative_queue_panel == null:
		push_error(
			"BattleHUD: InitiativeQueuePanel was not found. "
			+ "Make sure the panel instance is marked "
			+ "as a unique node."
		)
		return false

	if not unit_info_panel.has_signal(
		"end_turn_requested"
	):
		push_error(
			"BattleHUD: UnitInfoPanel does not provide "
			+ "the 'end_turn_requested' signal."
		)
		return false

	if not unit_info_panel.has_signal(
		"ability_selected"
	):
		push_error(
			"BattleHUD: UnitInfoPanel does not provide "
			+ "the 'ability_selected' signal."
		)
		return false

	return true
	
# ============================================================
# СОЕДИНЕНИЕ ДОЧЕРНИХ ПАНЕЛЕЙ
# ============================================================

func _connect_panels() -> bool:
	var end_turn_callback := Callable(
		self,
		"_on_unit_info_panel_end_turn_requested"
	)

	if not unit_info_panel.end_turn_requested.is_connected(
		end_turn_callback
	):
		unit_info_panel.end_turn_requested.connect(
			end_turn_callback
		)

	var ability_callback := Callable(
		self,
		"_on_unit_info_panel_ability_selected"
	)

	if not unit_info_panel.ability_selected.is_connected(
		ability_callback
	):
		unit_info_panel.ability_selected.connect(
			ability_callback
		)

	return true


func _on_unit_info_panel_end_turn_requested() -> void:
	print("BattleHUD: forwarding end turn intent")
	end_turn_requested.emit()
	
# ============================================================
# ПЕРЕДАЧА ВЫБОРА СПОСОБНОСТИ
# ============================================================

func _on_unit_info_panel_ability_selected(
	ability_runtime: UnitAbilityRuntime
) -> void:
	if ability_runtime == null or ability_runtime.data == null:
		push_error(
			"BattleHUD: selected ability is null"
		)
		return

	print(
		"BattleHUD: forwarding ability selection: ",
		ability_runtime.data.ability_name
	)

	ability_selected.emit(
		ability_runtime
	)
