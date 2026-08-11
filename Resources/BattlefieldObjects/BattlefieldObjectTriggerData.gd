extends Resource

class_name BattlefieldObjectTriggerData


enum TargetPolicy {
	EVENT_TARGET,
	ALL_UNITS_IN_COVERAGE
}


enum EventLocationPolicy {
	TARGET_CELL_IN_COVERAGE,
	SAME_TYPE_COVERAGE_CONTACT
}


@export var trigger_id : String = ""

@export var event_kind : CombatEvent.Kind = CombatEvent.Kind.ACTIVATION_ENDED

# Пустая строка принимает любой источник.
@export var source_type_filter : String = ""

@export_range(0, 999, 1) var minimum_applied_amount : int = 0

@export var accept_reaction_events : bool = true

@export var event_location_policy : EventLocationPolicy = (
	EventLocationPolicy.TARGET_CELL_IN_COVERAGE
)

@export var target_policy : TargetPolicy = TargetPolicy.EVENT_TARGET

@export var consume_object_on_trigger : bool = false

@export var response_plan_data : ImpactPlanData = null
