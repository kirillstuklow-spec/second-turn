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

# Индивидуальные эффекты

@export var effects : Array[EffectData] = []

# Индивидуальные ограничения

@export var conditions : Array[String] = []


# ============================================================
# СТОИМОСТЬ И RUNTIME-ОГРАНИЧЕНИЯ
# ============================================================

# Ноль означает бесплатную способность.
@export_range(0, 99, 1) var action_point_cost : int = 1

# Кулдаун измеряется полными последующими раундами владельца.
@export_range(0, 99, 1) var cooldown_rounds : int = 0

# Ноль означает, что заряды не ограничены.
@export_range(0, 99, 1) var max_charges : int = 0

# Ноль в любом из лимитов означает отсутствие этого лимита.
@export_range(0, 99, 1) var max_uses_per_battle : int = 0

@export_range(0, 99, 1) var max_uses_per_round : int = 0

@export_range(0, 99, 1) var max_uses_per_activation : int = 0
