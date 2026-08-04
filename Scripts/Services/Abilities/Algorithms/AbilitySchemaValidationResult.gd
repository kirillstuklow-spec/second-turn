extends RefCounted

class_name AbilitySchemaValidationResult


var unit_ability : UnitAbilityData = null

var algorithm_definition : AbilityAlgorithmDefinition = null

var is_valid : bool = true

var resolved_parameters : Dictionary = {}

var issues : Array[AbilitySchemaIssue] = []


func add_issue(
	issue_code : AbilitySchemaIssue.Code,
	field_path : String,
	context : Dictionary = {}
) -> void:
	is_valid = false
	issues.append(
		AbilitySchemaIssue.create(
			issue_code,
			field_path,
			context
		)
	)


func has_issue(issue_code : AbilitySchemaIssue.Code) -> bool:
	for issue in issues:
		if issue != null and issue.code == issue_code:
			return true

	return false


func get_summary() -> String:
	if issues.is_empty():
		return "Схема способности корректна."

	var messages := PackedStringArray()

	for issue in issues:
		if issue == null:
			continue

		var prefix := ""

		if not issue.field_path.is_empty():
			prefix = issue.field_path + ": "

		messages.append(prefix + issue.get_message())

	return "\n".join(messages)

