extends RefCounted

class_name AbilityAvailabilityResult


var ability_runtime : UnitAbilityRuntime = null

var is_available : bool = true

var reasons : Array[AbilityAvailabilityReason] = []


func add_reason(
	reason_code : int,
	reason_context : Dictionary = {}
) -> void:
	is_available = false
	reasons.append(
		AbilityAvailabilityReason.create(
			reason_code,
			reason_context
		)
	)


func has_reason(reason_code : int) -> bool:
	for reason in reasons:
		if reason != null and reason.code == reason_code:
			return true

	return false


func get_summary() -> String:
	if reasons.is_empty():
		return "Способность доступна."

	var messages := PackedStringArray()

	for reason in reasons:
		if reason == null:
			continue

		messages.append(reason.get_message())

	return "\n".join(messages)
