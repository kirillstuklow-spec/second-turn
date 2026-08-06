extends RefCounted

class_name CombatEventLog


var history : Array[CombatEvent] = []

var _next_event_sequence : int = 1


func record_impact_result(
	impact_result : ImpactResult,
	battle_state : BattleState = null
) -> CombatEvent:
	if (
		impact_result == null
		or impact_result.impact == null
		or not impact_result.was_applied()
	):
		return null

	var impact := impact_result.impact
	var event_kind : CombatEvent.Kind

	match impact.operation:
		Impact.Operation.DAMAGE:
			if impact_result.magnitude_applied <= 0:
				return null
			event_kind = CombatEvent.Kind.DAMAGE_APPLIED

		Impact.Operation.HEAL:
			if impact_result.magnitude_applied <= 0:
				return null
			event_kind = CombatEvent.Kind.HEALING_APPLIED

		Impact.Operation.APPLY_EFFECT:
			var application_result := (
				impact_result.effect_application_result
			)

			if (
				application_result == null
				or not application_result.was_applied_or_refreshed()
			):
				return null

			if (
				application_result.status
				== EffectApplicationResult.Status.REFRESHED
			):
				event_kind = CombatEvent.Kind.EFFECT_REFRESHED
			else:
				event_kind = CombatEvent.Kind.EFFECT_APPLIED

		_:
			return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = event_kind
	event.execution_id = impact.execution_id
	event.root_execution_id = impact.root_execution_id
	event.impact_id = impact.impact_id
	event.source_unit = impact.source_unit
	event.target_unit = impact.target_unit
	event.applied_amount = impact_result.magnitude_applied
	event.source_type = impact.source_type
	event.interaction_type = impact.interaction_type
	event.origin_effect_runtime_id = impact.origin_effect_runtime_id
	event.reaction_depth = impact.reaction_depth
	_stamp_event_time(event, battle_state)

	if impact_result.effect_application_result != null:
		var effect_runtime := (
			impact_result.effect_application_result.effect_runtime
		)

		if effect_runtime != null:
			event.applied_effect_runtime_id = effect_runtime.runtime_id
			event.effect_id = effect_runtime.get_effect_id()

	_next_event_sequence += 1
	history.append(event)
	return event


func record_unit_event(
	event_kind : CombatEvent.Kind,
	unit : UnitRuntime,
	battle_state : BattleState
) -> CombatEvent:
	if event_kind != CombatEvent.Kind.ACTIVATION_ENDED:
		return null

	if (
		unit == null
		or battle_state == null
		or not battle_state.units.has(unit)
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = event_kind
	event.execution_id = StringName(
		"activation_execution_%06d_end"
		% battle_state.turn_state.activation_serial
	)
	event.root_execution_id = event.execution_id
	event.source_unit = unit
	event.target_unit = unit
	_stamp_event_time(event, battle_state)

	_next_event_sequence += 1
	history.append(event)
	return event


func clear() -> void:
	history.clear()
	_next_event_sequence = 1


func _stamp_event_time(
	event : CombatEvent,
	battle_state : BattleState
) -> void:
	if event == null or battle_state == null:
		return

	event.activation_serial = battle_state.turn_state.activation_serial
	event.round_number = battle_state.round_number
