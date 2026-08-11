extends Resource

class_name ImpactNodeData


enum SourceReference {
	ABILITY_SOURCE,
	EFFECT_SOURCE,
	EVENT_SOURCE,
	EFFECT_CARRIER,
	BATTLEFIELD_OBJECT_SOURCE
}


enum TargetReference {
	SELECTED_TARGET,
	ABILITY_SOURCE,
	EFFECT_CARRIER,
	EVENT_SOURCE,
	EVENT_TARGET
}


enum MagnitudeSource {
	FIXED,
	EVENT_APPLIED_AMOUNT
}


enum MagnitudeRounding {
	FLOOR,
	CEIL
}


@export var node_id : String = ""

@export var parent_node_id : String = ""

@export var source_reference : SourceReference = (
	SourceReference.ABILITY_SOURCE
)

@export var target_reference : TargetReference = (
	TargetReference.SELECTED_TARGET
)

@export var operation : Impact.Operation = Impact.Operation.DAMAGE

@export var interaction_type : Impact.InteractionType = (
	Impact.InteractionType.MELEE
)

@export var source_type : String = ""

# HEAL допускает отрицательную величину: это изменение HP через HEALING,
# а не Damage. Остальные операции проверяют собственные диапазоны.
@export_range(-999, 999, 1) var magnitude : int = 0

# FIXED использует magnitude. EVENT_APPLIED_AMOUNT берёт фактически
# применённую величину события и масштабирует её рациональным коэффициентом.
@export var magnitude_source : MagnitudeSource = MagnitudeSource.FIXED

@export_range(1, 999, 1) var magnitude_numerator : int = 1

@export_range(1, 999, 1) var magnitude_denominator : int = 1

@export var magnitude_rounding : MagnitudeRounding = MagnitudeRounding.FLOOR

@export_range(-5, 5, 1) var armor_penetration : int = 0

@export var healing_kind : Impact.HealingKind = Impact.HealingKind.DIRECT

@export var effect_data : EffectData = null

# Один SUMMON-узел создаёт один новый UnitRuntime из этого неизменяемого
# профиля. Команда призыва наследуется от источника Impact.
@export var summon_unit_data : UnitData = null

# Один CREATE_OBJECT-узел создаёт один runtime-экземпляр объекта поля.
@export var battlefield_object_data : BattlefieldObjectData = null

@export var transition_condition : ImpactConditionData = null

@export var metadata : Dictionary = {}
