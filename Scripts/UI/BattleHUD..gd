extends Control

class_name BattleHUD

signal end_turn_requested


# ============================================================
# ДОЧЕРНИЕ ПАНЕЛИ
# ============================================================

@onready var unit_info_panel: UnitInfoPanel = (
	get_node_or_null("%UnitInfoPanel") as UnitInfoPanel
)
# ============================================================
# ОБНОВЛЕНИЕ HUD
# ============================================================

func show_unit(unit: UnitRuntime) -> void:
	if unit_info_panel == null:
		push_error(
			"BattleHUD: UnitInfoPanel is missing"
		)
		return

	unit_info_panel.show_unit(unit)
	
	
func _ready() -> void:
	if not _validate_hud():
		return

	if not _connect_panels():
		return

	print("BattleHUD: panels connected")


func _validate_hud() -> bool:
	if unit_info_panel == null:
		push_error(
			"BattleHUD: UnitInfoPanel was not found. "
			+ "Make sure the panel instance is marked as a unique node."
		)
		return false

	if not unit_info_panel.has_signal("end_turn_requested"):
		push_error(
			"BattleHUD: UnitInfoPanel does not provide "
			+ "the 'end_turn_requested' signal."
		)
		return false

	return true


func _connect_panels() -> bool:
	var end_turn_callback := Callable(
		self,
		"_on_unit_info_panel_end_turn_requested"
	)

	if not unit_info_panel.is_connected(
		"end_turn_requested",
		end_turn_callback
	):
		unit_info_panel.connect(
			"end_turn_requested",
			end_turn_callback
		)

	return true


func _on_unit_info_panel_end_turn_requested() -> void:
	print("BattleHUD: forwarding end turn intent")
	end_turn_requested.emit()
