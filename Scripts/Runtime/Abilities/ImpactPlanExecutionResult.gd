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

var reaction_execution_results : Array[ImpactPlanExecutionResult] = []

var issues : PackedStringArray = PackedStringArray()

var pending_decision : PendingDecision = null


func is_successful() -> bool:
	return status == Status.EXECUTED


func is_waiting_for_decision() -> bool:
	return is_successful() and pending_decision != null


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


func get_all_impact_results() -> Array[ImpactResult]:
	var all_results : Array[ImpactResult] = []
	all_results.append_array(impact_results)

	for reaction_result in reaction_execution_results:
		if reaction_result != null:
			all_results.append_array(
				reaction_result.get_all_impact_results()
			)

	return all_results
