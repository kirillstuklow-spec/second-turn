extends RefCounted

class_name BattleRngRollResult


var roll_id : StringName = &""

var sequence_number : int = 0

var purpose : StringName = &""

var minimum_value : int = 0

var maximum_value : int = 0

var value : int = 0

var state_before : int = 0

var state_after : int = 0

var context : Dictionary = {}


static func create(
	new_roll_id : StringName,
	new_sequence_number : int,
	new_purpose : StringName,
	new_minimum_value : int,
	new_maximum_value : int,
	new_value : int,
	new_state_before : int,
	new_state_after : int,
	new_context : Dictionary = {}
) -> BattleRngRollResult:
	var result := BattleRngRollResult.new()
	result.roll_id = new_roll_id
	result.sequence_number = new_sequence_number
	result.purpose = new_purpose
	result.minimum_value = new_minimum_value
	result.maximum_value = new_maximum_value
	result.value = new_value
	result.state_before = new_state_before
	result.state_after = new_state_after
	result.context = new_context.duplicate(true)
	return result

