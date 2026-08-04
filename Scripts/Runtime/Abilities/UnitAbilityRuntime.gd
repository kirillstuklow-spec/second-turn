extends RefCounted

class_name UnitAbilityRuntime


const UNLIMITED_CHARGES : int = -1


# ============================================================
# НЕИЗМЕНЯЕМЫЕ ССЫЛКИ
# ============================================================

var data : UnitAbilityData = null

var _owner_ref : WeakRef = null

var owner : UnitRuntime:
	get:
		if _owner_ref == null:
			return null

		return _owner_ref.get_ref() as UnitRuntime


# ============================================================
# ИЗМЕНЯЕМОЕ СОСТОЯНИЕ СПОСОБНОСТИ В БОЮ
# ============================================================

var remaining_cooldown : int = 0

var remaining_charges : int = UNLIMITED_CHARGES

var uses_this_battle : int = 0

var uses_this_round : int = 0

var uses_this_activation : int = 0


# ============================================================
# ИДЕНТИФИКАТОРЫ ПОСЛЕДНЕГО ПРИМЕНЕНИЯ
# ============================================================

var last_execution_id : StringName = &""

var last_used_round : int = -1

var last_used_activation_index : int = -1


# ============================================================
# ТЕКУЩИЙ LIFECYCLE-КОНТЕКСТ
# ============================================================

var current_round_number : int = 0

var current_activation_index : int = -1


# ============================================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================================

func setup(
	ability_data : UnitAbilityData,
	ability_owner : UnitRuntime
) -> void:
	if ability_data == null:
		push_error(
			"UnitAbilityRuntime setup failed: "
			+ "ability_data is null"
		)
		return

	if ability_owner == null:
		push_error(
			"UnitAbilityRuntime setup failed: owner is null"
		)
		return

	data = ability_data
	_owner_ref = weakref(ability_owner)

	remaining_cooldown = 0
	remaining_charges = UNLIMITED_CHARGES

	if data.max_charges > 0:
		remaining_charges = data.max_charges

	uses_this_battle = 0
	uses_this_round = 0
	uses_this_activation = 0

	last_execution_id = &""
	last_used_round = -1
	last_used_activation_index = -1

	current_round_number = 0
	current_activation_index = -1


# ============================================================
# ЖИЗНЕННЫЙ ЦИКЛ РАУНДА И АКТИВАЦИИ
# ============================================================

func start_round(round_number : int) -> void:
	if round_number == current_round_number:
		return

	current_round_number = round_number
	current_activation_index = -1
	uses_this_round = 0
	uses_this_activation = 0


func finish_round(completed_round_number : int) -> void:
	if remaining_cooldown <= 0:
		return

	# Раунд, в котором способность была применена, не считается
	# полным раундом ожидания кулдауна.
	if last_used_round >= completed_round_number:
		return

	remaining_cooldown -= 1


func start_activation(
	round_number : int,
	activation_index : int
) -> void:
	start_round(round_number)

	current_activation_index = activation_index
	uses_this_activation = 0


# ============================================================
# ЗАРЯДЫ И ФИКСАЦИЯ ПРИМЕНЕНИЯ
# ============================================================

func has_limited_charges() -> bool:
	return data != null and data.max_charges > 0


func record_use(
	execution_id : StringName,
	round_number : int,
	activation_index : int
) -> bool:
	if data == null or owner == null:
		push_error(
			"UnitAbilityRuntime: cannot record use without data and owner"
		)
		return false

	if has_limited_charges():
		if remaining_charges <= 0:
			push_error(
				"UnitAbilityRuntime: cannot consume a missing charge"
			)
			return false

		remaining_charges -= 1

	uses_this_battle += 1
	uses_this_round += 1
	uses_this_activation += 1

	remaining_cooldown = data.cooldown_rounds

	last_execution_id = execution_id
	last_used_round = round_number
	last_used_activation_index = activation_index

	return true
