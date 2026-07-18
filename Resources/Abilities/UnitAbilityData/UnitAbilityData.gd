extends Resource
class_name UnitAbilityData

# Название способности

@export var ability_name : String

# Лорное описание

@export_multiline var description : String

# Используемый игровой механизм

@export var ability : AbilityData

# Индивидуальные параметры

@export var parameters : Dictionary = {}

# Индивидуальные эффекты

@export var effects : Array[EffectData] = []

# Индивидуальные ограничения

@export var conditions : Array[String] = []
