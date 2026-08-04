extends RefCounted

class_name ImpactPlanBuildResult


var is_valid : bool = true

var plan : ImpactPlan = null

var message : String = ""


func reject(error_message : String) -> ImpactPlanBuildResult:
	is_valid = false
	message = error_message
	plan = null
	return self
