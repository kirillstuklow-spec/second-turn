extends RefCounted

class_name BattleState


# ============================================================
# КОНСТАНТЫ ПОЛЯ БОЯ
# ============================================================

const FIELD_WIDTH : int = 7
const FIELD_HEIGHT : int = 5


# ============================================================
# СОСТОЯНИЕ БОЯ
# ============================================================

var is_battle_over: bool = false

var winner_team_id: int = 0


# ============================================================
# СОСТОЯНИЕ СИСТЕМЫ ХОДОВ
# ============================================================

var turn_state: TurnState = TurnState.new()


# Временный совместимый доступ.
# Настоящее значение хранится в TurnState.
var round_number: int:
	get:
		return turn_state.round_number

	set(value):
		turn_state.round_number = value
# ============================================================
# КЛЕТКИ ПОЛЯ БОЯ
# ============================================================

var cells : Array[CellRuntime] = []


# ============================================================
# ЮНИТЫ В БОЮ
# ============================================================

var units : Array[UnitRuntime] = []


# ============================================================
# ТЕКУЩИЙ АКТИВНЫЙ ЮНИТ
# ============================================================

# Временный совместимый доступ.
# Настоящая ссылка хранится в TurnState.
var active_unit: UnitRuntime:
	get:
		return turn_state.active_unit

	set(value):
		turn_state.active_unit = value
# ============================================================
# ВЫБРАННАЯ СПОСОБНОСТЬ
# ============================================================

var pending_ability : UnitAbilityData = null


# ============================================================
# ОЧИСТКА СОСТОЯНИЯ
# ============================================================

func clear() -> void:
	cells.clear()
	units.clear()

	turn_state.clear()

	pending_ability = null

	is_battle_over = false
	winner_team_id = 0


func add_cell(cell : CellRuntime) -> void:
	if cell == null:
		push_error("BattleState: cannot add null cell")
		return

	cells.append(cell)


func add_unit(unit : UnitRuntime) -> void:
	if unit == null:
		push_error("BattleState: cannot add null unit")
		return

	units.append(unit)


func set_active_unit(unit : UnitRuntime) -> void:
	if unit == null:
		push_error("BattleState: cannot set active_unit to null")
		return

	active_unit = unit


func set_pending_ability(unit_ability : UnitAbilityData) -> void:
	if unit_ability == null:
		push_error("BattleState: cannot set pending_ability to null")
		return

	pending_ability = unit_ability


func clear_pending_ability() -> void:
	pending_ability = null


# ============================================================
# ГЕНЕРАЦИЯ ПОЛЯ БОЯ
# ============================================================

func generate_battlefield() -> void:
	cells.clear()

	for y in range(FIELD_HEIGHT):
		for x in range(FIELD_WIDTH):
			var cell : CellRuntime = CellRuntime.new()
			var zone : CellRuntime.CellZone = _get_zone_for_position(x, y)

			cell.setup(x, y, zone)
			add_cell(cell)

	print("BattleState: battlefield generated")
	print("Cells count: ", cells.size())


func _get_zone_for_position(x : int, y : int) -> CellRuntime.CellZone:
	# Верхняя и нижняя строки.
	if y == 0 or y == 4:
		if x >= 0 and x <= 2:
			return CellRuntime.CellZone.PLAYER_1_MAIN

		if x == 3:
			return CellRuntime.CellZone.NEUTRAL

		if x >= 4 and x <= 6:
			return CellRuntime.CellZone.PLAYER_2_MAIN

	# Центральные три строки.
	if y >= 1 and y <= 3:
		if x >= 0 and x <= 1:
			return CellRuntime.CellZone.PLAYER_1_DEPLOYMENT

		if x == 2:
			return CellRuntime.CellZone.PLAYER_1_MAIN

		if x == 3:
			return CellRuntime.CellZone.NEUTRAL

		if x == 4:
			return CellRuntime.CellZone.PLAYER_2_MAIN

		if x >= 5 and x <= 6:
			return CellRuntime.CellZone.PLAYER_2_DEPLOYMENT

	return CellRuntime.CellZone.NEUTRAL


# ============================================================
# СПАВН ЮНИТОВ
# ============================================================

func spawn_unit(unit_data : UnitData, team_id : int, x : int, y : int) -> UnitRuntime:
	if unit_data == null:
		push_error("BattleState: cannot spawn unit without UnitData")
		return null

	var cell : CellRuntime = get_cell_at(x, y)

	if cell == null:
		push_error("BattleState: cannot spawn unit, cell not found")
		return null

	if cell.is_occupied():
		push_error("BattleState: cannot spawn unit, cell is occupied")
		return null

	var unit : UnitRuntime = UnitRuntime.new()
	unit.setup(unit_data, team_id)

	cell.place_unit(unit)
	add_unit(unit)

	print("Spawned ", unit.data.unit_name, " at cell ", x, ",", y)

	return unit


# ============================================================
# ПОИСК КЛЕТОК И ЮНИТОВ
# ============================================================

func get_cell_at(x : int, y : int) -> CellRuntime:
	for cell in cells:
		if cell.x == x and cell.y == y:
			return cell

	return null


func get_unit_on_cell(cell : CellRuntime) -> UnitRuntime:
	if cell == null:
		return null

	return cell.occupying_unit


# ============================================================
# ДВИЖЕНИЕ
# ============================================================

func can_unit_move_to(unit : UnitRuntime, target_cell : CellRuntime) -> bool:
	if unit == null:
		push_error("BattleState: cannot move null unit")
		return false

	if unit.cell == null:
		push_error("BattleState: cannot move unit without cell")
		return false

	if target_cell == null:
		push_error("BattleState: cannot move to null cell")
		return false

	if not unit.is_alive:
		print("BattleState: cannot move dead unit")
		return false

	if target_cell.is_occupied():
		print("BattleState: cannot move to occupied cell")
		return false

	if not _is_adjacent_orthogonal(unit.cell, target_cell):
		print("BattleState: target cell is not adjacent")
		return false

	return true


func move_unit(unit : UnitRuntime, target_cell : CellRuntime) -> bool:
	if not can_unit_move_to(unit, target_cell):
		return false

	var old_cell : CellRuntime = unit.cell
	var old_x : int = old_cell.x
	var old_y : int = old_cell.y

	old_cell.remove_unit()
	target_cell.place_unit(unit)

	print(
		"BattleState: moved ",
		unit.data.unit_name,
		" from ",
		old_x,
		",",
		old_y,
		" to ",
		target_cell.x,
		",",
		target_cell.y
	)

	return true


func _is_adjacent_orthogonal(from_cell : CellRuntime, to_cell : CellRuntime) -> bool:
	if from_cell == null or to_cell == null:
		return false

	var dx : int = abs(from_cell.x - to_cell.x)
	var dy : int = abs(from_cell.y - to_cell.y)

	return dx + dy == 1


# ============================================================
# СМЕРТЬ И ОЧИСТКА КЛЕТОК
# ============================================================

func cleanup_dead_units() -> void:
	for unit in units:
		if unit == null:
			continue

		if unit.is_alive:
			continue

		if unit.cell != null:
			print("BattleState: removing dead unit from cell: ", unit.data.unit_name)
			unit.cell.remove_unit()


# ============================================================
# ПРОВЕРКА ПОБЕДЫ
# ============================================================

func check_victory_condition() -> bool:
	if is_battle_over:
		return true

	var team_1_alive : int = count_alive_units_for_team(1)
	var team_2_alive : int = count_alive_units_for_team(2)

	print("Victory check | team 1 alive: ", team_1_alive, " | team 2 alive: ", team_2_alive)

	if team_1_alive > 0 and team_2_alive <= 0:
		_finish_battle(1)
		return true

	if team_2_alive > 0 and team_1_alive <= 0:
		_finish_battle(2)
		return true

	if team_1_alive <= 0 and team_2_alive <= 0:
		_finish_battle(0)
		return true

	return false


func count_alive_units_for_team(team_id : int) -> int:
	var alive_count : int = 0

	for unit in units:
		if unit == null:
			continue

		if not unit.is_alive:
			continue

		if unit.team_id != team_id:
			continue

		alive_count += 1

	return alive_count


# ============================================================
# ЗАВЕРШЕНИЕ БОЯ
# ============================================================

func _finish_battle(
	winning_team_id: int
) -> void:
	is_battle_over = true
	winner_team_id = winning_team_id

	turn_state.phase = TurnState.Phase.BATTLE_END

	clear_pending_ability()

	print("")
	print("========================================")

	if winner_team_id == 0:
		print("Battle finished: draw")
	else:
		print(
			"Battle finished: team ",
			winner_team_id,
			" wins"
		)

	print("========================================")
	
# ============================================================
# ОТЛАДКА: ВЫВОД ЗОН ПОЛЯ
# ============================================================

func print_battlefield_zones() -> void:
	print("")
	print("Battlefield zones:")

	for y in range(FIELD_HEIGHT):
		var row_text : String = ""

		for x in range(FIELD_WIDTH):
			var cell : CellRuntime = get_cell_at(x, y)

			if cell == null:
				row_text += "[?]"
			else:
				row_text += _get_zone_short_name(cell.zone)

		print(row_text)


func _get_zone_short_name(zone : CellRuntime.CellZone) -> String:
	if zone == CellRuntime.CellZone.PLAYER_1_DEPLOYMENT:
		return "[D1]"

	if zone == CellRuntime.CellZone.PLAYER_1_MAIN:
		return "[P1]"

	if zone == CellRuntime.CellZone.NEUTRAL:
		return "[N]"

	if zone == CellRuntime.CellZone.PLAYER_2_MAIN:
		return "[P2]"

	if zone == CellRuntime.CellZone.PLAYER_2_DEPLOYMENT:
		return "[D2]"

	return "[?]"


# ============================================================
# ОТЛАДКА: ВЫВОД ЮНИТОВ
# ============================================================

func print_units() -> void:
	print("")
	print("Units in BattleState:")

	for unit in units:
		if unit == null:
			print("Null unit in BattleState")
			continue

		if unit.cell == null:
			print(
				unit.data.unit_name,
				" | team: ",
				unit.team_id,
				" | no cell",
				" | HP: ",
				unit.current_hp,
				" | alive: ",
				unit.is_alive
			)
		else:
			print(
				unit.data.unit_name,
				" | team: ",
				unit.team_id,
				" | cell: ",
				unit.cell.x,
				",",
				unit.cell.y,
				" | HP: ",
				unit.current_hp,
				" | alive: ",
				unit.is_alive
			)
			
