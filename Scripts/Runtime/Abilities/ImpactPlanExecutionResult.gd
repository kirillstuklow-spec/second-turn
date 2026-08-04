extends RefCounted

class_name ImpactPlanExecutionResult


enum Status {
	EXECUTED,
	VALIDATION_FAILED,
	INTERNAL_ERROR
}


var status : Status = Status.VALIDATION_FAILED

var plan : ImpactPlan = null

var impact_results : Array[ImpactResult] = []

var issues : PackedStringArray = PackedStringArray()


func is_successful() -> bool:
	return status == Status.EXECUTED


func get_result(
	impact_id : StringName
) -> ImpactResult:
	for result in impact_results:
		if (
			result != null
			and result.impact != null
			and result.impact.impact_id == impact_id
		):
			return result

	return null


func get_summary() -> String:
	if issues.is_empty():
		if status == Status.EXECUTED:
			return "План воздействий исполнен."

		return "План воздействий не исполнен."

	return "\n".join(issues)
