extends Resource

class_name AbilityData


enum ActivationMode {
	ACTIVE,
	PASSIVE,
	TRIGGERED
}


enum ActionType {
	ATTACK,
	HEAL,
	SUMMON
}


enum TargetingForm {
	MELEE,
	RANGED,
	MAGIC
}


# -----------------------
# Основная информация механизма
# -----------------------

@export var mechanism_name : String = ""

@export_multiline var technical_description : String = ""


# -----------------------
# Классификация механизма
# -----------------------

@export var activation_mode : ActivationMode = ActivationMode.ACTIVE

@export var action_type : ActionType = ActionType.ATTACK

@export var targeting_form : TargetingForm = TargetingForm.MELEE


# -----------------------
# Правила запуска и исполнения
# -----------------------

@export var trigger_id : String = ""

@export var algorithm_id : String = ""

@export var target_rule_id : String = ""


# -----------------------
# Универсальные настройки механизма
# -----------------------

@export var default_parameters : Dictionary = {}

@export var default_conditions : Array[String] = []
