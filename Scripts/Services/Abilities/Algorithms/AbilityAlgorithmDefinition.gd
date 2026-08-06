extends RefCounted

class_name AbilityAlgorithmDefinition


var algorithm_id : StringName = &""

var display_name : String = ""

var description : String = ""

var action_type : int = AbilityData.ActionType.ATTACK

var allows_any_action_type : bool = false

var allowed_target_rules : Array[StringName] = []

var parameter_specs : Array[AbilityParameterSpec] = []


func get_parameter_spec(
	parameter_id : StringName
) -> AbilityParameterSpec:
	for parameter_spec in parameter_specs:
		if (
			parameter_spec != null
			and parameter_spec.parameter_id == parameter_id
		):
			return parameter_spec

	return null


func allows_target_rule(target_rule_id : StringName) -> bool:
	return allowed_target_rules.has(target_rule_id)


func allows_action_type(value : int) -> bool:
	return allows_any_action_type or value == action_type
