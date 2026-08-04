extends RefCounted

class_name AbilityAlgorithmDefinition


var algorithm_id : StringName = &""

var display_name : String = ""

var description : String = ""

var action_type : int = AbilityData.ActionType.ATTACK

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

