extends Resource

class_name ImpactConditionData


enum ConditionType {
	ALWAYS,
	PARENT_APPLIED,
	PARENT_MAGNITUDE_APPLIED_AT_LEAST,
	PARENT_EFFECT_APPLIED_OR_REFRESHED
}


@export var condition_type : ConditionType = (
	ConditionType.PARENT_APPLIED
)

@export_range(0, 999, 1) var minimum_magnitude : int = 1
