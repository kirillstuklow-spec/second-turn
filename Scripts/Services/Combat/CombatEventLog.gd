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

		Impact.Operation.SUMMON:
			if impact_result.summoned_unit == null:
				return null
			event_kind = CombatEvent.Kind.UNIT_SUMMONED

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
	event.source_ability_data = impact.source_ability_data
	event.target_unit = impact.target_unit

	if impact.operation == Impact.Operation.SUMMON:
		event.target_unit = impact_result.summoned_unit

	_capture_unit_cell(event, impact.source_unit, true)
	_capture_unit_cell(event, event.target_unit, false)
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
	_capture_unit_cell(event, unit, true)
	_capture_unit_cell(event, unit, false)
	_stamp_event_time(event, battle_state)

	_next_event_sequence += 1
	history.append(event)
	return event


func record_death_event(
	unit : UnitRuntime,
	cause_event : CombatEvent,
	battle_state : BattleState
) -> CombatEvent:
	if (
		unit == null
		or battle_state == null
		or not battle_state.units.has(unit)
		or not unit.is_dead()
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.DEATH_CONFIRMED
	event.target_unit = unit
	event.target_cell = unit.death_origin_cell
	event.target_cell_x = unit.death_origin_x
	event.target_cell_y = unit.death_origin_y

	if cause_event != null:
		event.cause_event_id = cause_event.event_id
		event.execution_id = cause_event.execution_id
		event.root_execution_id = cause_event.root_execution_id
		event.impact_id = cause_event.impact_id
		event.source_unit = cause_event.source_unit
		event.source_ability_data = cause_event.source_ability_data
		event.source_type = cause_event.source_type
		event.interaction_type = cause_event.interaction_type
		event.origin_effect_runtime_id = (
			cause_event.origin_effect_runtime_id
		)
		event.reaction_depth = cause_event.reaction_depth
		event.source_cell = cause_event.source_cell
		event.source_cell_x = cause_event.source_cell_x
		event.source_cell_y = cause_event.source_cell_y
	else:
		event.execution_id = StringName(
			"death_execution_%06d" % _next_event_sequence
		)
		event.root_execution_id = event.execution_id

	_stamp_event_time(event, battle_state)
	_next_event_sequence += 1
	history.append(event)
	return event


func record_death_prevented_event(
	unit : UnitRuntime,
	cause_event : CombatEvent,
	prevention_effect : EffectRuntime,
	battle_state : BattleState
) -> CombatEvent:
	if (
		unit == null
		or battle_state == null
		or not battle_state.units.has(unit)
		or not unit.is_alive
		or prevention_effect == null
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.DEATH_PREVENTED
	event.source_unit = prevention_effect.source_unit
	event.source_ability_data = prevention_effect.source_ability_data
	event.target_unit = unit
	event.applied_amount = unit.current_hp
	event.interaction_type = Impact.InteractionType.EFFECT
	event.origin_effect_runtime_id = prevention_effect.runtime_id
	event.applied_effect_runtime_id = prevention_effect.runtime_id
	event.effect_id = prevention_effect.get_effect_id()

	if cause_event != null:
		event.cause_event_id = cause_event.event_id
		event.execution_id = cause_event.execution_id
		event.root_execution_id = cause_event.root_execution_id
		event.impact_id = cause_event.impact_id
		event.reaction_depth = cause_event.reaction_depth + 1
	else:
		event.execution_id = StringName(
			"death_prevention_execution_%06d" % _next_event_sequence
		)
		event.root_execution_id = event.execution_id

	_capture_unit_cell(event, event.source_unit, true)
	_capture_unit_cell(event, unit, false)
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


func _capture_unit_cell(
	event : CombatEvent,
	unit : UnitRuntime,
	is_source : bool
) -> void:
	if event == null or unit == null:
		return

	var runtime_cell := unit.cell as CellRuntime
	var cell_x := -1
	var cell_y := -1

	if runtime_cell != null:
		cell_x = runtime_cell.x
		cell_y = runtime_cell.y
	elif unit.death_origin_cell != null:
		runtime_cell = unit.death_origin_cell
		cell_x = unit.death_origin_x
		cell_y = unit.death_origin_y

	if is_source:
		event.source_cell = runtime_cell
		event.source_cell_x = cell_x
		event.source_cell_y = cell_y
	else:
		event.target_cell = runtime_cell
		event.target_cell_x = cell_x
		event.target_cell_y = cell_y
