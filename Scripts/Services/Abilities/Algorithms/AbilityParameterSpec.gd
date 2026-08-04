extends RefCounted

class_name AbilityParameterSpec


enum ValueType {
	INTEGER,
	FLOAT,
	BOOLEAN,
	STRING
}


var parameter_id : StringName = &""

var display_name : String = ""

var description : String = ""

var value_type : ValueType = ValueType.INTEGER

var is_required : bool = false

var required_target_rules : Array[StringName] = []

var has_default_value : bool = false

var default_value : Variant = null

var has_minimum : bool = false

var minimum_value : float = 0.0

var has_maximum : bool = false

var maximum_value : float = 0.0

var allow_empty_string : bool = true

var reject_surrounding_whitespace : bool = false


func is_required_for(target_rule_id : StringName) -> bool:
	if is_required:
		return true

	return required_target_rules.has(target_rule_id)


func accepts_type(value : Variant) -> bool:
	match value_type:
		ValueType.INTEGER:
			return typeof(value) == TYPE_INT

		ValueType.FLOAT:
			return typeof(value) == TYPE_FLOAT

		ValueType.BOOLEAN:
			return typeof(value) == TYPE_BOOL

		ValueType.STRING:
			return typeof(value) == TYPE_STRING

	return false


func get_expected_type_name() -> String:
	match value_type:
		ValueType.INTEGER:
			return "int"

		ValueType.FLOAT:
			return "float"

		ValueType.BOOLEAN:
			return "bool"

		ValueType.STRING:
			return "String"

	return "unknown"

