extends RefCounted

class_name EffectApplicationResult


enum Status {
	APPLIED,
	REFRESHED,
	UNCHANGED,
	REJECTED
}


var status : Status = Status.REJECTED

var effect_runtime : EffectRuntime = null

var message : String = ""


static func create(
	new_status : Status,
	new_effect_runtime : EffectRuntime = null,
	new_message : String = ""
) -> EffectApplicationResult:
	var result := EffectApplicationResult.new()
	result.status = new_status
	result.effect_runtime = new_effect_runtime
	result.message = new_message
	return result


func was_applied_or_refreshed() -> bool:
	return status in [Status.APPLIED, Status.REFRESHED]
