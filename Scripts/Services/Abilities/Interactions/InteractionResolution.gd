extends RefCounted

class_name InteractionResolution


enum Outcome {
	ALLOWED,
	BLOCKED_IMMUNITY,
	BLOCKED_DEFENSE,
	BLOCKED_ARMOR,
	INVALID
}


# Порядок значений повторяет фактическую иерархию проверки.
enum Stage {
	NONE,
	IMMUNITY_INTERACTION_TYPE,
	IMMUNITY_SOURCE_TYPE,
	DEFENSE_INTERACTION_TYPE,
	DEFENSE_SOURCE_TYPE,
	ARMOR
}


var impact : Impact = null

var outcome : Outcome = Outcome.INVALID

var stage : Stage = Stage.NONE

var interaction_type_tag : StringName = &""

var source_type_tag : StringName = &""

var matched_tag : StringName = &""

var defense_to_consume : StringName = &""

var armor_was_checked : bool = false

var effective_armor : int = 0

var block_chance : int = 0

var armor_roll : BattleRngRollResult = null

var message : String = ""


static func create(
	new_impact : Impact
) -> InteractionResolution:
	var resolution := InteractionResolution.new()
	resolution.impact = new_impact
	resolution.outcome = Outcome.ALLOWED
	return resolution


func is_allowed() -> bool:
	return outcome == Outcome.ALLOWED


func was_blocked() -> bool:
	return outcome in [
		Outcome.BLOCKED_IMMUNITY,
		Outcome.BLOCKED_DEFENSE,
		Outcome.BLOCKED_ARMOR
	]


func requires_defense_consumption() -> bool:
	return (
		outcome == Outcome.BLOCKED_DEFENSE
		and defense_to_consume != &""
	)


func get_outcome_id() -> StringName:
	match outcome:
		Outcome.ALLOWED:
			return &"allowed"

		Outcome.BLOCKED_IMMUNITY:
			return &"blocked_immunity"

		Outcome.BLOCKED_DEFENSE:
			return &"blocked_defense"

		Outcome.BLOCKED_ARMOR:
			return &"blocked_armor"

		Outcome.INVALID:
			return &"invalid"

	return &"unknown"


func get_stage_id() -> StringName:
	match stage:
		Stage.NONE:
			return &"none"

		Stage.IMMUNITY_INTERACTION_TYPE:
			return &"immunity_interaction_type"

		Stage.IMMUNITY_SOURCE_TYPE:
			return &"immunity_source_type"

		Stage.DEFENSE_INTERACTION_TYPE:
			return &"defense_interaction_type"

		Stage.DEFENSE_SOURCE_TYPE:
			return &"defense_source_type"

		Stage.ARMOR:
			return &"armor"

	return &"unknown"
