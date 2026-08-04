extends RefCounted

class_name AbilityExecutionResult


enum Status {
	COMMITTED,
	REJECTED_INPUT,
	REJECTED_AVAILABILITY,
	REJECTED_SCHEMA,
	REJECTED_TARGET,
	REJECTED_PLAN,
	FAILED_COMMIT,
	FAILED_EXECUTION
}


var status : Status = Status.REJECTED_INPUT

var execution_id : StringName = &""

var message : String = ""

var targeting_result : TargetingResult = null

var impact_plan : ImpactPlan = null

var impact_execution_result : ImpactPlanExecutionResult = null


static func rejected(
	rejection_status : Status,
	rejection_message : String
) -> AbilityExecutionResult:
	var result := AbilityExecutionResult.new()
	result.status = rejection_status
	result.message = rejection_message
	return result


static func committed(
	new_execution_id : StringName,
	new_targeting_result : TargetingResult,
	new_impact_plan : ImpactPlan,
	new_impact_execution_result : ImpactPlanExecutionResult
) -> AbilityExecutionResult:
	var result := AbilityExecutionResult.new()
	result.status = Status.COMMITTED
	result.execution_id = new_execution_id
	result.message = "Способность исполнена."
	result.targeting_result = new_targeting_result
	result.impact_plan = new_impact_plan
	result.impact_execution_result = new_impact_execution_result
	return result


func was_committed() -> bool:
	return status == Status.COMMITTED


func get_impact_results() -> Array[ImpactResult]:
	if impact_execution_result == null:
		var empty_results : Array[ImpactResult] = []
		return empty_results

	return impact_execution_result.impact_results
