extends RefCounted

class_name ImpactConditionEvaluator


func is_satisfied(
	condition : ImpactConditionData,
	parent_result : ImpactResult
) -> bool:
	if parent_result == null:
		return false

	if condition == null:
		return parent_result.was_applied()

	match condition.condition_type:
		ImpactConditionData.ConditionType.ALWAYS:
			return true

		ImpactConditionData.ConditionType.PARENT_APPLIED:
			return parent_result.was_applied()

		ImpactConditionData.ConditionType.PARENT_MAGNITUDE_APPLIED_AT_LEAST:
			return (
				parent_result.was_applied()
				and parent_result.magnitude_applied
				>= condition.minimum_magnitude
			)

		ImpactConditionData.ConditionType.PARENT_EFFECT_APPLIED_OR_REFRESHED:
			var application_result := parent_result.effect_application_result
			return (
				parent_result.was_applied()
				and application_result != null
				and application_result.was_applied_or_refreshed()
			)

	return false
