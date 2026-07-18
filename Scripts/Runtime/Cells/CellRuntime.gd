extends RefCounted

class_name CellRuntime


enum CellZone {
	PLAYER_1_DEPLOYMENT,
	PLAYER_1_MAIN,
	NEUTRAL,
	PLAYER_2_MAIN,
	PLAYER_2_DEPLOYMENT
}


# -----------------------
# Координаты клетки
# -----------------------

var x : int = 0

var y : int = 0


# -----------------------
# Зона поля боя
# -----------------------

var zone : CellZone = CellZone.NEUTRAL


# -----------------------
# Занятость клетки
# -----------------------

var occupying_unit : UnitRuntime = null


# -----------------------
# Инициализация
# -----------------------

func setup(cell_x : int, cell_y : int, cell_zone : CellZone) -> void:
	x = cell_x
	y = cell_y
	zone = cell_zone
	occupying_unit = null


# -----------------------
# Проверки
# -----------------------

func is_occupied() -> bool:
	return occupying_unit != null


func is_empty() -> bool:
	return occupying_unit == null


# -----------------------
# Управление занятостью
# -----------------------

func place_unit(unit : UnitRuntime) -> void:
	if unit == null:
		push_error("CellRuntime: cannot place null unit")
		return

	if occupying_unit != null:
		push_error("CellRuntime: cell is already occupied")
		return

	occupying_unit = unit
	unit.cell = self


func remove_unit() -> void:
	if occupying_unit != null:
		occupying_unit.cell = null

	occupying_unit = null
	
	
