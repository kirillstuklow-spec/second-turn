extends Resource

class_name UnitData


enum UnitSize {
	NORMAL = 1,
	LARGE = 2,
	HUGE = 4
}


# -----------------------
# Основная информация
# -----------------------

@export var unit_id : String = ""

@export var unit_name : String = ""

@export_multiline var description : String = ""


# -----------------------
# Принадлежность и развитие
# -----------------------

@export var faction : String = ""

@export var unit_class : String = ""

@export var experience_to_level : int = 0


# -----------------------
# Боевые характеристики
# -----------------------

@export var initiative : int = 0

@export var max_hp : int = 1

@export var armor : int = 0

@export var movement : int = 3

@export var size : UnitSize = UnitSize.NORMAL


# -----------------------
# Постоянные свойства
# -----------------------

@export var defenses : Array[String] = []

@export var immunities : Array[String] = []

@export var keywords : Array[String] = []


# -----------------------
# Способности
# -----------------------

@export var active_abilities : Array[UnitAbilityData] = []

@export var passive_abilities : Array[UnitAbilityData] = []



# -----------------------
# Визуальные данные
# -----------------------

@export var visual_data : UnitVisualData = null
