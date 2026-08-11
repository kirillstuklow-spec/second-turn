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

		Impact.Operation.MOVE:
			if (
				impact_result.movement_from_cell == null
				or impact_result.movement_to_cell == null
				or impact_result.magnitude_applied <= 0
			):
				return null
			event_kind = CombatEvent.Kind.UNIT_MOVED

		Impact.Operation.CREATE_OBJECT:
			if impact_result.created_battlefield_object == null:
				return null
			event_kind = CombatEvent.Kind.BATTLEFIELD_OBJECT_CREATED

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
	event.source_object = impact.source_object
	event.source_ability_data = impact.source_ability_data
	event.target_unit = impact.target_unit

	if impact.operation == Impact.Operation.SUMMON:
		event.target_unit = impact_result.summoned_unit

	if impact.operation == Impact.Operation.CREATE_OBJECT:
		event.battlefield_object = (
			impact_result.created_battlefield_object
		)
		event.battlefield_object_runtime_id = (
			event.battlefield_object.runtime_id
		)
		event.battlefield_object_id = (
			event.battlefield_object.get_object_id()
		)

	_capture_unit_cell(event, impact.source_unit, true)
	_capture_unit_cell(event, event.target_unit, false)

	if impact.operation == Impact.Operation.MOVE:
		event.source_cell = impact_result.movement_from_cell
		event.source_cell_x = impact_result.movement_from_cell.x
		event.source_cell_y = impact_result.movement_from_cell.y
		event.target_cell = impact_result.movement_to_cell
		event.target_cell_x = impact_result.movement_to_cell.x
		event.target_cell_y = impact_result.movement_to_cell.y
	elif impact.operation == Impact.Operation.CREATE_OBJECT:
		event.target_cell = impact.target_cell
		event.target_cell_x = impact.target_cell.x
		event.target_cell_y = impact.target_cell.y

	event.applied_amount = impact_result.magnitude_applied
	event.hp_delta = impact_result.hp_after - impact_result.hp_before
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


# Создаёт производное событие для любой фактической потери HP от Impact.
# Исходное DAMAGE_APPLIED или HEALING_APPLIED остаётся в журнале и продолжает
# обслуживать реакции, завязанные именно на природу воздействия.
func record_health_loss_from_impact_result(
	impact_result : ImpactResult,
	cause_event : CombatEvent,
	battle_state : BattleState = null
) -> CombatEvent:
	if (
		impact_result == null
		or impact_result.impact == null
		or not impact_result.was_applied()
		or impact_result.hp_after >= impact_result.hp_before
	):
		return null

	var impact := impact_result.impact
	var loss_cause := CombatEvent.HealthLossCause.NONE

	match impact.operation:
		Impact.Operation.DAMAGE:
			loss_cause = CombatEvent.HealthLossCause.DAMAGE

		Impact.Operation.HEAL:
			if impact.magnitude >= 0:
				return null
			loss_cause = CombatEvent.HealthLossCause.NEGATIVE_HEALING

		_:
			return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.HEALTH_LOST
	event.execution_id = impact.execution_id
	event.root_execution_id = impact.root_execution_id
	event.impact_id = impact.impact_id
	event.source_unit = impact.source_unit
	event.source_object = impact.source_object
	event.source_ability_data = impact.source_ability_data
	event.target_unit = impact.target_unit
	event.applied_amount = impact_result.hp_before - impact_result.hp_after
	event.hp_delta = -event.applied_amount
	event.health_loss_cause = loss_cause
	event.source_type = impact.source_type
	event.interaction_type = impact.interaction_type
	event.origin_effect_runtime_id = impact.origin_effect_runtime_id
	event.reaction_depth = impact.reaction_depth

	if cause_event != null:
		event.cause_event_id = cause_event.event_id
		event.source_cell = cause_event.source_cell
		event.source_cell_x = cause_event.source_cell_x
		event.source_cell_y = cause_event.source_cell_y
		event.target_cell = cause_event.target_cell
		event.target_cell_x = cause_event.target_cell_x
		event.target_cell_y = cause_event.target_cell_y
	else:
		_capture_unit_cell(event, impact.source_unit, true)
		_capture_unit_cell(event, impact.target_unit, false)

	_stamp_event_time(event, battle_state)
	_next_event_sequence += 1
	history.append(event)
	return event


# HP-цена не становится Impact и не проходит защиты, но после успешной
# фиксации способности публикует тот же факт HEALTH_LOST для общих реакций.
func record_health_point_cost_event(
	unit : UnitRuntime,
	ability_data : UnitAbilityData,
	execution_id : StringName,
	hp_before : int,
	hp_after : int,
	battle_state : BattleState = null
) -> CombatEvent:
	if (
		unit == null
		or ability_data == null
		or ability_data.ability == null
		or execution_id == &""
		or hp_after >= hp_before
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.HEALTH_LOST
	event.execution_id = execution_id
	event.root_execution_id = execution_id
	event.impact_id = StringName("%s_health_point_cost" % execution_id)
	event.source_unit = unit
	event.source_object = unit
	event.source_ability_data = ability_data
	event.target_unit = unit
	event.applied_amount = hp_before - hp_after
	event.hp_delta = -event.applied_amount
	event.health_loss_cause = CombatEvent.HealthLossCause.ABILITY_COST
	event.interaction_type = Impact.interaction_type_from_ability(
		ability_data.ability
	)
	_capture_unit_cell(event, unit, true)
	_capture_unit_cell(event, unit, false)
	_stamp_event_time(event, battle_state)

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
	event.source_object = unit
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
		event.source_object = cause_event.source_object
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
	event.source_object = prevention_effect
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


# Пространственное событие создаётся только когда применённый Impact попал в
# клетку, уже покрытую объектом. Оно не заменяет DAMAGE_APPLIED и не меняет HP.
func record_spatial_impact_event(
	impact_result : ImpactResult,
	battle_state : BattleState
) -> CombatEvent:
	if (
		impact_result == null
		or impact_result.impact == null
		or not impact_result.was_applied()
		or battle_state == null
	):
		return null

	var impact := impact_result.impact

	if impact.operation not in [
		Impact.Operation.DAMAGE,
		Impact.Operation.HEAL,
		Impact.Operation.APPLY_EFFECT,
		Impact.Operation.AFFECT_CELL
	]:
		return null

	var target_cell := impact.target_cell

	if (
		target_cell == null
		or battle_state.get_battlefield_objects_covering_cell(
			target_cell
		).is_empty()
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.IMPACT_APPLIED
	event.execution_id = impact.execution_id
	event.root_execution_id = impact.root_execution_id
	event.impact_id = impact.impact_id
	event.source_unit = impact.source_unit
	event.source_object = impact.source_object
	event.source_ability_data = impact.source_ability_data
	event.target_unit = impact.target_unit
	event.target_cell = target_cell
	event.target_cell_x = target_cell.x
	event.target_cell_y = target_cell.y
	event.applied_amount = impact_result.magnitude_applied
	event.hp_delta = impact_result.hp_after - impact_result.hp_before
	event.source_type = impact.source_type
	event.interaction_type = impact.interaction_type
	event.origin_effect_runtime_id = impact.origin_effect_runtime_id
	event.reaction_depth = impact.reaction_depth
	_capture_unit_cell(event, impact.source_unit, true)
	_stamp_event_time(event, battle_state)

	_next_event_sequence += 1
	history.append(event)
	return event


# Фиксирует сам факт разрешения воздействия в покрытой клетке. В отличие от
# IMPACT_APPLIED событие существует и для заблокированного воздействия, но не
# сообщает о повторном изменении HP.
func record_spatial_impact_resolved_event(
	impact_result : ImpactResult,
	battle_state : BattleState
) -> CombatEvent:
	if (
		impact_result == null
		or impact_result.impact == null
		or (
			not impact_result.was_applied()
			and not impact_result.was_blocked()
		)
		or battle_state == null
	):
		return null

	var impact := impact_result.impact

	if impact.operation not in [
		Impact.Operation.DAMAGE,
		Impact.Operation.HEAL,
		Impact.Operation.APPLY_EFFECT,
		Impact.Operation.AFFECT_CELL
	]:
		return null

	var target_cell := impact.target_cell

	if (
		target_cell == null
		or battle_state.get_battlefield_objects_covering_cell(
			target_cell
		).is_empty()
	):
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.IMPACT_RESOLVED
	event.execution_id = impact.execution_id
	event.root_execution_id = impact.root_execution_id
	event.impact_id = impact.impact_id
	event.source_unit = impact.source_unit
	event.source_object = impact.source_object
	event.source_ability_data = impact.source_ability_data
	event.target_unit = impact.target_unit
	event.target_cell = target_cell
	event.target_cell_x = target_cell.x
	event.target_cell_y = target_cell.y
	event.applied_amount = impact_result.magnitude_applied
	event.hp_delta = impact_result.hp_after - impact_result.hp_before
	event.impact_outcome = impact_result.get_outcome_id()
	event.source_type = impact.source_type
	event.interaction_type = impact.interaction_type
	event.origin_effect_runtime_id = impact.origin_effect_runtime_id
	event.reaction_depth = impact.reaction_depth
	_capture_unit_cell(event, impact.source_unit, true)
	_stamp_event_time(event, battle_state)

	_next_event_sequence += 1
	history.append(event)
	return event


func record_battlefield_object_triggered_event(
	task : ReactionTask,
	battle_state : BattleState
) -> CombatEvent:
	if (
		task == null
		or task.source_battlefield_object == null
		or task.battlefield_object_trigger_data == null
		or battle_state == null
	):
		return null

	var object_runtime := task.source_battlefield_object
	var trigger_data := task.battlefield_object_trigger_data
	var cause_event := task.trigger_event
	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.BATTLEFIELD_OBJECT_TRIGGERED
	event.execution_id = task.execution_id
	event.root_execution_id = task.root_execution_id
	event.source_unit = object_runtime.source_unit
	event.source_object = object_runtime
	event.source_ability_data = object_runtime.source_ability_data
	event.battlefield_object = object_runtime
	event.battlefield_object_runtime_id = object_runtime.runtime_id
	event.battlefield_object_id = object_runtime.get_object_id()
	event.battlefield_object_trigger_id = StringName(trigger_data.trigger_id)
	event.target_cell = object_runtime.anchor_cell
	event.applied_amount = 1
	event.interaction_type = Impact.InteractionType.OBJECT
	event.reaction_depth = task.reaction_depth

	if object_runtime.anchor_cell != null:
		event.target_cell_x = object_runtime.anchor_cell.x
		event.target_cell_y = object_runtime.anchor_cell.y

	if cause_event != null:
		event.cause_event_id = cause_event.event_id
		event.source_type = cause_event.source_type

	_capture_unit_cell(event, object_runtime.source_unit, true)
	_stamp_event_time(event, battle_state)
	_next_event_sequence += 1
	history.append(event)
	return event


func record_battlefield_object_removed_event(
	object_runtime : BattlefieldObjectRuntime,
	reason : StringName,
	cause_event : CombatEvent,
	battle_state : BattleState
) -> CombatEvent:
	if object_runtime == null or battle_state == null:
		return null

	var event := CombatEvent.new()
	event.event_id = StringName(
		"combat_event_%06d" % _next_event_sequence
	)
	event.kind = CombatEvent.Kind.BATTLEFIELD_OBJECT_REMOVED
	event.battlefield_object = object_runtime
	event.battlefield_object_runtime_id = object_runtime.runtime_id
	event.battlefield_object_id = object_runtime.get_object_id()
	event.object_removal_reason = reason
	event.source_unit = object_runtime.source_unit
	event.source_object = object_runtime
	event.source_ability_data = object_runtime.source_ability_data
	event.target_cell = object_runtime.anchor_cell

	if object_runtime.anchor_cell != null:
		event.target_cell_x = object_runtime.anchor_cell.x
		event.target_cell_y = object_runtime.anchor_cell.y

	if cause_event != null:
		event.cause_event_id = cause_event.event_id
		event.execution_id = cause_event.execution_id
		event.root_execution_id = cause_event.root_execution_id
		event.impact_id = cause_event.impact_id
		event.reaction_depth = cause_event.reaction_depth + 1
	else:
		event.execution_id = StringName(
			"object_removal_%06d" % _next_event_sequence
		)
		event.root_execution_id = event.execution_id

	_capture_unit_cell(event, object_runtime.source_unit, true)
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
