extends RefCounted

class_name UnitRuntime


# ============================================================
# DATA-РЕСУРС И БАЗОВОЕ СОСТОЯНИЕ
# ============================================================

var data : UnitData
var current_hp : int = 0
var team_id : int = 0
var cell = null
var is_alive : bool = true


# ============================================================
# БОЕВЫЕ ПАРАМЕТРЫ
# ============================================================

var armor : int = 0
var active_defenses : Array[String] = []
var active_immunities : Array[String] = []


# ============================================================
# РЕСУРСЫ АКТИВАЦИИ
# ============================================================

var action_points_remaining : int = 0
var movement_points_remaining : int = 0

var initiative_modifier_this_round : int = 0
var initiative_roll_this_round : int = 0

# ============================================================
# НАСТРОЙКА ЮНИТА
# ============================================================

func setup(unit_data : UnitData, unit_team_id : int) -> void:
	if unit_data == null:
		push_error("UnitRuntime setup failed: unit_data is null")
		return

	data = unit_data
	team_id = unit_team_id

	current_hp = data.max_hp
	armor = data.armor

	active_defenses = data.defenses.duplicate()
	active_immunities = data.immunities.duplicate()

	is_alive = current_hp > 0

	action_points_remaining = 0
	movement_points_remaining = 0
	
	initiative_modifier_this_round = 0
	initiative_roll_this_round = data.initiative

# ============================================================
# СТАРТ АКТИВАЦИИ
# ============================================================

func start_activation() -> void:
	if data == null:
		push_error("UnitRuntime: cannot start activation without UnitData")
		return

	if not is_alive:
		action_points_remaining = 0
		movement_points_remaining = 0
		return

	action_points_remaining = 1
	movement_points_remaining = data.movement

	print(
		"Activation resources for ",
		data.unit_name,
		" | AP: ",
		action_points_remaining,
		" | MP: ",
		movement_points_remaining
	)
# ============================================================
# ИНИЦИАТИВА РАУНДА
# ============================================================

func set_round_initiative_modifier(modifier : int) -> void:
	if data == null:
		push_error("UnitRuntime: cannot set initiative roll without UnitData")
		return

	initiative_modifier_this_round = modifier
	initiative_roll_this_round = data.initiative + initiative_modifier_this_round

# ============================================================
# ПРОВЕРКА И ТРАТА ДЕЙСТВИЯ
# ============================================================

func can_spend_action_points(amount : int) -> bool:
	if amount <= 0:
		return true

	if not is_alive:
		return false

	return action_points_remaining >= amount


func spend_action_points(amount : int) -> bool:
	if not can_spend_action_points(amount):
		print(data.unit_name, " has not enough action points")
		return false

	action_points_remaining -= amount

	print(
		data.unit_name,
		" spent ",
		amount,
		" AP | remaining AP: ",
		action_points_remaining
	)

	return true


# ============================================================
# ПРОВЕРКА И ТРАТА ДВИЖЕНИЯ
# ============================================================

func can_spend_movement_points(amount : int) -> bool:
	if amount <= 0:
		return true

	if not is_alive:
		return false

	return movement_points_remaining >= amount


func spend_movement_points(amount : int) -> bool:
	if not can_spend_movement_points(amount):
		print(data.unit_name, " has not enough movement points")
		return false

	movement_points_remaining -= amount

	print(
		data.unit_name,
		" spent ",
		amount,
		" MP | remaining MP: ",
		movement_points_remaining
	)

	return true


# ============================================================
# ЗАЩИТЫ И ИММУНИТЕТЫ
# ============================================================

func has_defense(keyword : String) -> bool:
	return active_defenses.has(keyword)


func consume_defense(keyword : String) -> void:
	active_defenses.erase(keyword)


func has_immunity(keyword : String) -> bool:
	return active_immunities.has(keyword)


# ============================================================
# УРОН И ЛЕЧЕНИЕ
# ============================================================

func take_damage(amount : int) -> void:
	if amount <= 0:
		return

	current_hp -= amount

	if current_hp <= 0:
		current_hp = 0
		is_alive = false
		action_points_remaining = 0
		movement_points_remaining = 0


func heal(amount : int) -> void:
	if amount <= 0:
		return

	if not is_alive:
		return

	current_hp += amount

	if current_hp > data.max_hp:
		current_hp = data.max_hp
