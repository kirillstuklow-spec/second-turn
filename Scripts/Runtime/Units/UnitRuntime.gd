extends RefCounted

class_name UnitRuntime


enum DeathState {
	ALIVE,
	DEATH_PENDING,
	DEAD
}


# ============================================================
# DATA-РЕСУРС И БАЗОВОЕ СОСТОЯНИЕ
# ============================================================

var data : UnitData
var current_hp : int = 0
var team_id : int = 0
var cell = null
var is_alive : bool = true
var death_state : DeathState = DeathState.ALIVE

# Клетка сохраняется после подтверждения смерти. Она нужна посмертным
# реакциям, которые выбирают цель относительно места гибели уже после того,
# как сама клетка освобождена.
var death_origin_cell : CellRuntime = null
var death_origin_x : int = -1
var death_origin_y : int = -1


# ============================================================
# ПРОИСХОЖДЕНИЕ ПРИЗВАННОГО ЭКЗЕМПЛЯРА
# ============================================================

# Эти поля относятся к конкретному runtime-экземпляру. Тот же UnitData можно
# поставить в стартовый состав, и тогда он не считается призванным.
var summoned_by_unit : UnitRuntime = null
var summon_source_ability_data : UnitAbilityData = null
var summon_execution_id : StringName = &""
var summoned_round_number : int = 0


# ============================================================
# СПОСОБНОСТИ ЭТОГО ЭКЗЕМПЛЯРА ЮНИТА
# ============================================================

var active_abilities : Array[UnitAbilityRuntime] = []

var passive_abilities : Array[UnitAbilityRuntime] = []


# ============================================================
# БОЕВЫЕ ПАРАМЕТРЫ
# ============================================================

var armor : int = 0
var active_defenses : Array[String] = []
var active_immunities : Array[String] = []

var active_effects : Array[EffectRuntime] = []


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
	active_effects.clear()

	_initialize_ability_runtimes()

	is_alive = current_hp > 0
	death_state = (
		DeathState.ALIVE if is_alive else DeathState.DEATH_PENDING
	)
	_clear_death_origin()
	_clear_summon_origin()

	action_points_remaining = 0
	movement_points_remaining = 0
	
	initiative_modifier_this_round = 0
	initiative_roll_this_round = data.initiative


func mark_summoned(
	summoner : UnitRuntime,
	source_ability_data : UnitAbilityData,
	execution_id : StringName,
	round_number : int
) -> void:
	summoned_by_unit = summoner
	summon_source_ability_data = source_ability_data
	summon_execution_id = execution_id
	summoned_round_number = round_number


func was_summoned_in_battle() -> bool:
	return summoned_by_unit != null and summon_execution_id != &""


func _clear_summon_origin() -> void:
	summoned_by_unit = null
	summon_source_ability_data = null
	summon_execution_id = &""
	summoned_round_number = 0


func _initialize_ability_runtimes() -> void:
	active_abilities.clear()
	passive_abilities.clear()

	if data == null:
		return

	for ability_data in data.active_abilities:
		var ability_runtime := _create_ability_runtime(
			ability_data
		)

		if ability_runtime != null:
			active_abilities.append(ability_runtime)

	for ability_data in data.passive_abilities:
		var ability_runtime := _create_ability_runtime(
			ability_data
		)

		if ability_runtime != null:
			passive_abilities.append(ability_runtime)


func _create_ability_runtime(
	ability_data : UnitAbilityData
) -> UnitAbilityRuntime:
	if ability_data == null:
		push_error(
			"UnitRuntime: UnitData contains a null ability"
		)
		return null

	var ability_runtime := UnitAbilityRuntime.new()
	ability_runtime.setup(ability_data, self)
	return ability_runtime


func get_active_ability_runtime(
	ability_data : UnitAbilityData
) -> UnitAbilityRuntime:
	if ability_data == null:
		return null

	for ability_runtime in active_abilities:
		if (
			ability_runtime != null
			and ability_runtime.data == ability_data
		):
			return ability_runtime

	return null


# ============================================================
# СТАРТ И ЗАВЕРШЕНИЕ РАУНДА
# ============================================================

func start_round(round_number : int) -> void:
	for ability_runtime in active_abilities:
		if ability_runtime != null:
			ability_runtime.start_round(round_number)

	for ability_runtime in passive_abilities:
		if ability_runtime != null:
			ability_runtime.start_round(round_number)


func finish_round(round_number : int) -> void:
	for ability_runtime in active_abilities:
		if ability_runtime != null:
			ability_runtime.finish_round(round_number)

	for ability_runtime in passive_abilities:
		if ability_runtime != null:
			ability_runtime.finish_round(round_number)

# ============================================================
# СТАРТ АКТИВАЦИИ
# ============================================================

func start_activation(
	round_number : int = 0,
	activation_index : int = -1
) -> void:
	if data == null:
		push_error("UnitRuntime: cannot start activation without UnitData")
		return

	if not is_alive:
		action_points_remaining = 0
		movement_points_remaining = 0
		return

	action_points_remaining = 1
	movement_points_remaining = data.movement

	for ability_runtime in active_abilities:
		if ability_runtime != null:
			ability_runtime.start_activation(
				round_number,
				activation_index
			)

	for ability_runtime in passive_abilities:
		if ability_runtime != null:
			ability_runtime.start_activation(
				round_number,
				activation_index
			)

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


func get_active_effect(effect_id : StringName) -> EffectRuntime:
	if effect_id == &"":
		return null

	for effect_runtime in active_effects:
		if (
			effect_runtime != null
			and effect_runtime.get_effect_id() == effect_id
		):
			return effect_runtime

	return null


# ============================================================
# УРОН И ЛЕЧЕНИЕ
# ============================================================

func take_damage(amount : int) -> void:
	if amount <= 0:
		return

	if death_state != DeathState.ALIVE:
		return

	current_hp -= amount

	if current_hp <= 0:
		begin_death_pending()


func heal(amount : int) -> void:
	if amount <= 0:
		return

	if not is_alive:
		return

	current_hp += amount

	if current_hp > data.max_hp:
		current_hp = data.max_hp


# ============================================================
# ЖИЗНЕННЫЙ ЦИКЛ СМЕРТИ
# ============================================================

func begin_death_pending() -> bool:
	if death_state != DeathState.ALIVE:
		return false

	current_hp = 0
	is_alive = false
	death_state = DeathState.DEATH_PENDING
	action_points_remaining = 0
	movement_points_remaining = 0
	_capture_death_origin()
	return true


func cancel_pending_death(restored_hp : int = 1) -> bool:
	if death_state != DeathState.DEATH_PENDING:
		return false

	if data == null or data.max_hp <= 0:
		return false

	current_hp = clampi(restored_hp, 1, data.max_hp)
	is_alive = true
	death_state = DeathState.ALIVE
	_clear_death_origin()
	return true


func confirm_death() -> bool:
	if death_state == DeathState.DEAD:
		return false

	if death_state == DeathState.ALIVE and current_hp > 0:
		return false

	_capture_death_origin()
	current_hp = 0
	is_alive = false
	death_state = DeathState.DEAD
	action_points_remaining = 0
	movement_points_remaining = 0
	active_effects.clear()
	return true


func is_death_pending() -> bool:
	return death_state == DeathState.DEATH_PENDING


func is_dead() -> bool:
	return death_state == DeathState.DEAD


func _capture_death_origin() -> void:
	if death_origin_cell != null or cell == null:
		return

	death_origin_cell = cell as CellRuntime
	death_origin_x = cell.x
	death_origin_y = cell.y


func _clear_death_origin() -> void:
	death_origin_cell = null
	death_origin_x = -1
	death_origin_y = -1
