extends RefCounted

class_name DecisionResolutionResult


enum Status {
	RESOLVED,
	REJECTED_NO_DECISION,
	REJECTED_ID,
	REJECTED_OPTION,
	FAILED_EXECUTION
}


var status : Status = Status.REJECTED_NO_DECISION

var message : String = ""

var selected_target : UnitRuntime = null

var root_execution_result : ImpactPlanExecutionResult = null


static func resolved(
	target : UnitRuntime,
	execution_result : ImpactPlanExecutionResult
) -> DecisionResolutionResult:
	var result := DecisionResolutionResult.new()
	result.status = Status.RESOLVED
	result.message = "Решение принято."
	result.selected_target = target
	result.root_execution_result = execution_result
	return result


static func rejected(
	rejection_status : Status,
	rejection_message : String
) -> DecisionResolutionResult:
	var result := DecisionResolutionResult.new()
	result.status = rejection_status
	result.message = rejection_message
	return result


func was_resolved() -> bool:
	return status == Status.RESOLVED
