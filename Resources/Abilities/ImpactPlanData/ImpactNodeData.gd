extends Resource

class_name ImpactNodeData


enum SourceReference {
	ABILITY_SOURCE,
	EFFECT_SOURCE,
	EVENT_SOURCE,
	EFFECT_CARRIER
}


enum TargetReference {
	SELECTED_TARGET,
	ABILITY_SOURCE,
	EFFECT_CARRIER,
	EVENT_SOURCE,
	EVENT_TARGET
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

@export_range(0, 999, 1) var magnitude : int = 0

@export_range(-5, 5, 1) var armor_penetration : int = 0

@export var healing_kind : Impact.HealingKind = Impact.HealingKind.DIRECT

@export var effect_data : EffectData = null

@export var transition_condition : ImpactConditionData = null

@export var metadata : Dictionary = {}
