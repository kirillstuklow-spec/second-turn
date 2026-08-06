extends RefCounted

class_name CombatEvent


enum Kind {
	DAMAGE_APPLIED,
	HEALING_APPLIED,
	EFFECT_APPLIED,
	EFFECT_REFRESHED,
	ACTIVATION_ENDED
}


var event_id : StringName = &""

var kind : Kind = Kind.DAMAGE_APPLIED

var execution_id : StringName = &""

var root_execution_id : StringName = &""

var impact_id : StringName = &""

var source_unit : UnitRuntime = null

var target_unit : UnitRuntime = null

var applied_amount : int = 0

var source_type : StringName = &""

var interaction_type : Impact.InteractionType = Impact.InteractionType.MELEE

var origin_effect_runtime_id : StringName = &""

var applied_effect_runtime_id : StringName = &""

var effect_id : StringName = &""

var reaction_depth : int = 0

# Время фиксируется в самом событии, чтобы поставленная реакция не зависела
# от более позднего изменения TurnState.
var activation_serial : int = -1

var round_number : int = 0
