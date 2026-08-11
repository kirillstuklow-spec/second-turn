extends Resource
class_name UnitAbilityData


# Название способности

@export var ability_name : String = ""

# Лорное описание

@export_multiline var description : String = ""

# Используемый игровой механизм

@export var ability : AbilityData = null

# Индивидуальные параметры

@export var parameters : Dictionary = {}

# Декларативный план конкретной способности. Если поле назначено,
# Ability Builder сможет редактировать дерево Impact без GDScript.
@export var impact_plan_data : ImpactPlanData = null

# Триггеры автоматического применения этой способности. Они используются
# только при AbilityData.activation_mode == TRIGGERED. Сам ответ хранится в
# impact_plan_data этой же способности, а не в данных эффекта.
@export var triggers : Array[AbilityTriggerData] = []

# Индивидуальные эффекты

@export var effects : Array[EffectData] = []

# Индивидуальные ограничения

@export var conditions : Array[String] = []


# ============================================================
# СТОИМОСТЬ И RUNTIME-ОГРАНИЧЕНИЯ
# ============================================================

# Ноль означает бесплатную способность.
@export_range(0, 99, 1) var action_point_cost : int = 1

# Стоимость HP является именно ценой применения, а не уроном: защиты её не
# проверяют, но фактическая трата создаёт HEALTH_LOST для общих реакций на
# утрату здоровья. Последний HP тратить нельзя.
@export_range(0, 99, 1) var health_point_cost : int = 0

# Кулдаун измеряется полными последующими раундами владельца.
@export_range(0, 99, 1) var cooldown_rounds : int = 0

# Ноль означает, что заряды не ограничены.
@export_range(0, 99, 1) var max_charges : int = 0

# Ноль в любом из лимитов означает отсутствие этого лимита.
@export_range(0, 99, 1) var max_uses_per_battle : int = 0

@export_range(0, 99, 1) var max_uses_per_round : int = 0

@export_range(0, 99, 1) var max_uses_per_activation : int = 0
