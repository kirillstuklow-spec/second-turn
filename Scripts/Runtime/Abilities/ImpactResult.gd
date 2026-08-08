extends RefCounted

class_name ImpactResult


enum Outcome {
	APPLIED,
	BLOCKED_IMMUNITY,
	BLOCKED_DEFENSE,
	BLOCKED_ARMOR,
	SKIPPED_PARENT,
	SKIPPED_QUEUE_INTERRUPTED,
	INVALID_SOURCE,
	INVALID_TARGET,
	UNSUPPORTED_OPERATION,
	INVALID_INTERACTION,
	SKIPPED_CONDITION,
	BLOCKED_PASSIVE_RULE,
	INVALID_EFFECT,
	SUMMON_FAILED
}


var impact : Impact = null

var interaction_resolution : InteractionResolution = null

var effect_application_result : EffectApplicationResult = null

var blocking_effect_runtime : EffectRuntime = null

var summoned_unit : UnitRuntime = null

var outcome : Outcome = Outcome.INVALID_TARGET

var magnitude_requested : int = 0

var magnitude_applied : int = 0

var hp_before : int = 0

var hp_after : int = 0

var effective_armor : int = 0

var block_chance : int = 0

var armor_roll : BattleRngRollResult = null

var consumed_defense : StringName = &""

var message : String = ""


static func create(
	new_impact : Impact,
	new_outcome : Outcome
) -> ImpactResult:
	var result := ImpactResult.new()
	result.impact = new_impact
	result.outcome = new_outcome

	if new_impact != null:
		result.magnitude_requested = new_impact.magnitude

	return result


func was_applied() -> bool:
	return outcome == Outcome.APPLIED


func was_blocked() -> bool:
	return outcome in [
		Outcome.BLOCKED_IMMUNITY,
		Outcome.BLOCKED_DEFENSE,
		Outcome.BLOCKED_ARMOR,
		Outcome.BLOCKED_PASSIVE_RULE
	]


func get_outcome_id() -> StringName:
	match outcome:
		Outcome.APPLIED:
			return &"applied"

		Outcome.BLOCKED_IMMUNITY:
			return &"blocked_immunity"

		Outcome.BLOCKED_DEFENSE:
			return &"blocked_defense"

		Outcome.BLOCKED_ARMOR:
			return &"blocked_armor"

		Outcome.SKIPPED_PARENT:
			return &"skipped_parent"

		Outcome.SKIPPED_QUEUE_INTERRUPTED:
			return &"skipped_queue_interrupted"

		Outcome.INVALID_SOURCE:
			return &"invalid_source"

		Outcome.INVALID_TARGET:
			return &"invalid_target"

		Outcome.UNSUPPORTED_OPERATION:
			return &"unsupported_operation"

		Outcome.INVALID_INTERACTION:
			return &"invalid_interaction"

		Outcome.SKIPPED_CONDITION:
			return &"skipped_condition"

		Outcome.BLOCKED_PASSIVE_RULE:
			return &"blocked_passive_rule"

		Outcome.INVALID_EFFECT:
			return &"invalid_effect"

		Outcome.SUMMON_FAILED:
			return &"summon_failed"

	return &"unknown"
