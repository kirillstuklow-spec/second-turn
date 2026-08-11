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
	SUMMON,
	SUPPORT,
	MOVEMENT
}


enum TargetingForm {
	MELEE,
	RANGED,
	MAGIC
}


enum ImpactPlanType {
	TREE,
	QUEUE
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

# Дерево продолжает независимые ветви, но не потомков
# неприменённого Impact. Очередь прерывает все следующие Impact.
@export var impact_plan_type : ImpactPlanType = ImpactPlanType.TREE


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
