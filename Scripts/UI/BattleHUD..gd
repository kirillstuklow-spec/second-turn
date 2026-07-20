extends Control

class_name BattleHUD

# ============================================================
# СИГНАЛЫ
# ============================================================

signal end_turn_requested

signal ability_selected(
	unit_ability: UnitAbilityData
)

# ============================================================
# ДОЧЕРНИЕ ПАНЕЛИ
# ============================================================

@onready var unit_info_panel: UnitInfoPanel = (
	get_node_or_null("%UnitInfoPanel") as UnitInfoPanel
)
# ============================================================
# ОБНОВЛЕНИЕ HUD
# ============================================================

func show_unit(
	unit: UnitRuntime,
	is_active: bool
) -> void:
	if unit_info_panel == null:
		push_error(
			"BattleHUD: UnitInfoPanel is missing"
		)
		return

	unit_info_panel.show_unit(
		unit,
		is_active
	)
	
func _ready() -> void:
	if not _validate_hud():
		return

	if not _connect_panels():
		return

	print("BattleHUD: panels connected")

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
	unit_ability: UnitAbilityData
) -> void:
	if unit_ability == null:
		push_error(
			"BattleHUD: selected ability is null"
		)
		return

	print(
		"BattleHUD: forwarding ability selection: ",
		unit_ability.ability_name
	)

	ability_selected.emit(
		unit_ability
	)
