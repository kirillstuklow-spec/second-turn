extends Node

class_name AbilityPipeline


# ============================================================
# АЛГОРИТМЫ СПОСОБНОСТЕЙ
# ============================================================

const ALGORITHM_DEAL_DAMAGE : String = "deal_damage"
const ALGORITHM_HEAL_TARGET : String = "heal_target"


# ============================================================
# ПАРАМЕТРЫ СПОСОБНОСТЕЙ
# ============================================================

const PARAM_DAMAGE : String = "damage"
const PARAM_HEAL : String = "heal"
const PARAM_ARMOR_PENETRATION : String = "armor_penetration"
const PARAM_KEYWORD : String = "keyword"
const PARAM_RADIUS : String = "radius"


# ============================================================
# УСЛОВИЯ СПОСОБНОСТЕЙ
# ============================================================

const CONDITION_TARGET_MUST_BE_ALIVE : String = "target_must_be_alive"
const CONDITION_TARGET_MUST_BE_ENEMY : String = "target_must_be_enemy"
const CONDITION_TARGET_MUST_BE_ALLY : String = "target_must_be_ally"


# ============================================================
# ПРАВИЛА ВЫБОРА ЦЕЛИ
# ============================================================

const TARGET_RULE_ALL_ENEMIES : String = "all_enemies"
const TARGET_RULE_SINGLE_ADJACENT_ENEMY : String = "single_adjacent_enemy"
const TARGET_RULE_AREA_AROUND_UNIT : String = "area_around_unit"
const TARGET_RULE_AREA_AROUND_CELL : String = "area_around_cell"


# ============================================================
# ССЫЛКИ НА СОСТОЯНИЕ БОЯ
# ============================================================

var battle_state : BattleState = null


# ============================================================
# СЛУЧАЙНОСТЬ
# ============================================================

var rng : RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


# ============================================================
# НАСТРОЙКА PIPELINE
# ============================================================

func configure(new_battle_state : BattleState) -> void:
	battle_state = new_battle_state

	print("AbilityPipeline configured")


# ============================================================
# ГЛАВНЫЙ ВХОД В PIPELINE
# ============================================================

func execute_ability(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	unit_ability : UnitAbilityData,
	target_cell : CellRuntime = null
) -> void:
	if source_unit == null:
		push_error("AbilityPipeline failed: source_unit is null")
		return

	if not source_unit.is_alive:
		print("AbilityPipeline failed: source_unit is dead")
		return

	if not source_unit.can_spend_action_points(1):
		print("AbilityPipeline failed: source_unit has no action points")
		return
	
	if target_unit == null and target_cell == null:
		push_error("AbilityPipeline failed: both target_unit and target_cell are null")
		return

	if unit_ability == null:
		push_error("AbilityPipeline failed: unit_ability is null")
		return

	if unit_ability.ability == null:
		push_error("AbilityPipeline failed: unit_ability has no AbilityData")
		return

	var ability_data : AbilityData = unit_ability.ability

	print("")
	print("========================================")
	print(source_unit.data.unit_name, " uses ", unit_ability.ability_name, " on ", _get_target_description(target_unit, target_cell))

	var ability_was_executed : bool = true

	match ability_data.algorithm_id:
		ALGORITHM_DEAL_DAMAGE:
			_execute_damage_algorithm(source_unit, target_unit, target_cell, ability_data, unit_ability)

		ALGORITHM_HEAL_TARGET:
			_execute_heal_target(source_unit, target_unit, ability_data, unit_ability)

		_:
			ability_was_executed = false
			push_error("AbilityPipeline failed: unsupported algorithm_id: " + ability_data.algorithm_id)
			print("========================================")

	if ability_was_executed:
		source_unit.spend_action_points(1)


func _get_target_description(target_unit : UnitRuntime, target_cell : CellRuntime) -> String:
	if target_unit != null:
		return target_unit.data.unit_name

	if target_cell != null:
		return "cell " + str(target_cell.x) + "," + str(target_cell.y)

	return "unknown target"


# ============================================================
# МАРШРУТИЗАЦИЯ УРОНА
# ============================================================

func _execute_damage_algorithm(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	target_cell : CellRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if ability_data.target_rule_id == TARGET_RULE_ALL_ENEMIES:
		_execute_deal_damage_all_enemies(source_unit, ability_data, unit_ability)
		return

	if ability_data.target_rule_id == TARGET_RULE_AREA_AROUND_UNIT:
		_execute_deal_damage_area_around_unit(source_unit, target_unit, ability_data, unit_ability)
		return

	if ability_data.target_rule_id == TARGET_RULE_AREA_AROUND_CELL:
		_execute_deal_damage_area_around_cell(source_unit, target_cell, ability_data, unit_ability)
		return

	_execute_deal_damage(source_unit, target_unit, ability_data, unit_ability)


# ============================================================
# ОДИНОЧНЫЙ УРОН
# ============================================================

func _execute_deal_damage(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if target_unit == null:
		push_error("AbilityPipeline failed: target_unit is null for deal_damage")
		print("========================================")
		return

	var parameters : Dictionary = unit_ability.parameters

	var damage : int = int(parameters.get(PARAM_DAMAGE, 0))
	var armor_penetration : int = int(parameters.get(PARAM_ARMOR_PENETRATION, 0))
	var keyword : String = str(parameters.get(PARAM_KEYWORD, ""))

	print("Attack keyword: ", keyword)
	print("Base damage: ", damage)
	print("Armor penetration: ", armor_penetration)

	if not _check_target_rule(source_unit, target_unit, ability_data):
		print("Ability cancelled: target rule failed")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	if not _check_conditions(source_unit, target_unit, ability_data, unit_ability):
		print("Ability cancelled: conditions failed")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	if _check_immunity(target_unit, keyword):
		print(target_unit.data.unit_name, " has immunity: ", keyword)
		print("Immunity blocked the attack")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	if _check_defense(target_unit, keyword):
		print(target_unit.data.unit_name, " has defense: ", keyword)
		print("Defense blocked the attack")
		target_unit.consume_defense(keyword)
		print("Defense ", keyword, " removed")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	if _check_armor(target_unit, armor_penetration):
		print("Armor blocked the attack")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	target_unit.take_damage(damage)

	print("Damage dealt: ", damage)
	print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)

	_cleanup_after_damage(target_unit)

	print("========================================")


func _cleanup_after_damage(target_unit : UnitRuntime) -> void:
	if target_unit == null:
		return

	if not target_unit.is_alive:
		print(target_unit.data.unit_name, " is dead")

	if battle_state != null:
		battle_state.cleanup_dead_units()


# ============================================================
# УРОН ПО ВСЕМ ВРАГАМ
# ============================================================

func _execute_deal_damage_all_enemies(
	source_unit : UnitRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if battle_state == null:
		push_error("AbilityPipeline failed: battle_state is null")
		print("========================================")
		return

	print("Target rule: all_enemies")

	var targets_processed : int = 0

	for possible_target in battle_state.units:
		if possible_target == null:
			continue

		if not possible_target.is_alive:
			continue

		if possible_target.team_id == source_unit.team_id:
			continue

		print("")
		print("Mass attack target: ", possible_target.data.unit_name)

		_execute_deal_damage(
			source_unit,
			possible_target,
			ability_data,
			unit_ability
		)

		targets_processed += 1

	print("")
	print("All enemies attack finished. Targets processed: ", targets_processed)
	print("========================================")


# ============================================================
# УРОН ПО ПЛОЩАДИ ВОКРУГ ЮНИТА
# ============================================================

func _execute_deal_damage_area_around_unit(
	source_unit : UnitRuntime,
	center_unit : UnitRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if battle_state == null:
		push_error("AbilityPipeline failed: battle_state is null")
		print("========================================")
		return

	if center_unit == null:
		push_error("AbilityPipeline failed: center_unit is null")
		print("========================================")
		return

	if center_unit.cell == null:
		push_error("AbilityPipeline failed: center_unit has no cell")
		print("========================================")
		return

	var parameters : Dictionary = unit_ability.parameters
	var radius : int = int(parameters.get(PARAM_RADIUS, 1))

	print("Target rule: area_around_unit")
	print("Area center: ", center_unit.data.unit_name)
	print("Area radius: ", radius)

	if not _check_conditions(source_unit, center_unit, ability_data, unit_ability):
		print("Ability cancelled: center target conditions failed")
		print(center_unit.data.unit_name, " current HP = ", center_unit.current_hp)
		print("========================================")
		return

	var targets_processed : int = 0

	for possible_target in battle_state.units:
		if possible_target == null:
			continue

		if not possible_target.is_alive:
			continue

		if possible_target.cell == null:
			continue

		if not _is_cell_in_radius(center_unit.cell, possible_target.cell, radius):
			continue

		print("")
		print("Area attack target: ", possible_target.data.unit_name)

		_execute_deal_damage(
			source_unit,
			possible_target,
			ability_data,
			unit_ability
		)

		targets_processed += 1

	print("")
	print("Area attack finished. Targets processed: ", targets_processed)
	print("========================================")


# ============================================================
# УРОН ПО ПЛОЩАДИ ВОКРУГ КЛЕТКИ
# ============================================================

func _execute_deal_damage_area_around_cell(
	source_unit : UnitRuntime,
	center_cell : CellRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if battle_state == null:
		push_error("AbilityPipeline failed: battle_state is null")
		print("========================================")
		return

	if center_cell == null:
		push_error("AbilityPipeline failed: center_cell is null")
		print("========================================")
		return

	var parameters : Dictionary = unit_ability.parameters
	var radius : int = int(parameters.get(PARAM_RADIUS, 1))

	print("Target rule: area_around_cell")
	print("Area center cell: ", center_cell.x, ",", center_cell.y)
	print("Area radius: ", radius)

	var targets_processed : int = 0

	for possible_target in battle_state.units:
		if possible_target == null:
			continue

		if not possible_target.is_alive:
			continue

		if possible_target.cell == null:
			continue

		if possible_target.team_id == source_unit.team_id:
			continue

		if not _is_cell_in_radius(center_cell, possible_target.cell, radius):
			continue

		print("")
		print("Cell area attack target: ", possible_target.data.unit_name)

		_execute_deal_damage(
			source_unit,
			possible_target,
			ability_data,
			unit_ability
		)

		targets_processed += 1

	print("")
	print("Cell area attack finished. Targets processed: ", targets_processed)
	print("========================================")


# ============================================================
# ЛЕЧЕНИЕ
# ============================================================

func _execute_heal_target(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> void:
	if target_unit == null:
		push_error("AbilityPipeline failed: target_unit is null for heal_target")
		print("========================================")
		return

	var parameters : Dictionary = unit_ability.parameters
	var heal_amount : int = int(parameters.get(PARAM_HEAL, 0))

	print("Heal amount: ", heal_amount)

	if not _check_conditions(source_unit, target_unit, ability_data, unit_ability):
		print("Ability cancelled: conditions failed")
		print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
		print("========================================")
		return

	var old_hp : int = target_unit.current_hp

	target_unit.heal(heal_amount)

	var actual_heal : int = target_unit.current_hp - old_hp

	print("Healing done: ", actual_heal)
	print(target_unit.data.unit_name, " current HP = ", target_unit.current_hp)
	print("========================================")


# ============================================================
# ПРОВЕРКА ПРАВИЛ ВЫБОРА ЦЕЛИ
# ============================================================

func _check_target_rule(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	ability_data : AbilityData
) -> bool:
	if ability_data.target_rule_id == TARGET_RULE_SINGLE_ADJACENT_ENEMY:
		if source_unit.cell == null:
			push_error("AbilityPipeline: source_unit has no cell")
			return false

		if target_unit == null:
			push_error("AbilityPipeline: target_unit is null")
			return false

		if target_unit.cell == null:
			push_error("AbilityPipeline: target_unit has no cell")
			return false

		if not _are_cells_adjacent_orthogonal(source_unit.cell, target_unit.cell):
			print("Target rule failed: target is not adjacent")
			return false

	return true


# ============================================================
# ПРОВЕРКА УСЛОВИЙ СПОСОБНОСТИ
# ============================================================

func _check_conditions(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	ability_data : AbilityData,
	unit_ability : UnitAbilityData
) -> bool:
	if target_unit == null:
		push_error("AbilityPipeline: cannot check conditions for null target_unit")
		return false

	var all_conditions : Array[String] = []

	all_conditions.append_array(ability_data.default_conditions)
	all_conditions.append_array(unit_ability.conditions)

	for condition_id in all_conditions:
		if condition_id == CONDITION_TARGET_MUST_BE_ALIVE:
			if not target_unit.is_alive:
				print("Condition failed: target is not alive")
				return false

		elif condition_id == CONDITION_TARGET_MUST_BE_ENEMY:
			if source_unit.team_id == target_unit.team_id:
				print("Condition failed: target is not enemy")
				return false

		elif condition_id == CONDITION_TARGET_MUST_BE_ALLY:
			if source_unit.team_id != target_unit.team_id:
				print("Condition failed: target is not ally")
				return false

		else:
			print("Unknown condition ignored: ", condition_id)

	return true


# ============================================================
# ГЕОМЕТРИЯ КЛЕТОК
# ============================================================

func _are_cells_adjacent_orthogonal(from_cell : CellRuntime, to_cell : CellRuntime) -> bool:
	if from_cell == null or to_cell == null:
		return false

	var dx : int = abs(from_cell.x - to_cell.x)
	var dy : int = abs(from_cell.y - to_cell.y)

	return dx + dy == 1


func _is_cell_in_radius(center_cell : CellRuntime, target_cell : CellRuntime, radius : int) -> bool:
	if center_cell == null or target_cell == null:
		return false

	var dx : int = abs(center_cell.x - target_cell.x)
	var dy : int = abs(center_cell.y - target_cell.y)

	return dx + dy <= radius


# ============================================================
# ИММУНИТЕТЫ И ЗАЩИТЫ
# ============================================================

func _check_immunity(target_unit : UnitRuntime, keyword : String) -> bool:
	if keyword == "":
		return false

	return target_unit.has_immunity(keyword)


func _check_defense(target_unit : UnitRuntime, keyword : String) -> bool:
	if keyword == "":
		return false

	return target_unit.has_defense(keyword)


# ============================================================
# БРОНЯ
# ============================================================

func _check_armor(target_unit : UnitRuntime, armor_penetration : int) -> bool:
	var effective_armor : int = target_unit.armor - armor_penetration
	effective_armor = clamp(effective_armor, 0, 5)

	var block_chance : int = effective_armor * 20

	print("Armor = ", target_unit.armor)
	print("Effective armor = ", effective_armor)
	print("Block chance = ", block_chance, "%")

	if block_chance <= 0:
		print("Armor did not block")
		return false

	var roll : int = rng.randi_range(1, 100)

	print("Armor roll: ", roll)

	if roll <= block_chance:
		print("Armor roll result: success")
		return true

	print("Armor roll result: failure")
	return false
	
