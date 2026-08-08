extends RefCounted

class_name DeathResolver


var _lethal_events_by_unit_id : Dictionary = {}


func observe_combat_event(event : CombatEvent) -> void:
	if (
		event == null
		or event.kind != CombatEvent.Kind.DAMAGE_APPLIED
		or event.target_unit == null
		or not event.target_unit.is_death_pending()
	):
		return

	_lethal_events_by_unit_id[event.target_unit.get_instance_id()] = event


func confirm_pending_deaths(
	battle_state : BattleState,
	combat_event_log : CombatEventLog
) -> Array[CombatEvent]:
	var death_events : Array[CombatEvent] = []

	if battle_state == null or combat_event_log == null:
		return death_events

	for unit in battle_state.units:
		if unit == null:
			continue

		var unit_instance_id := unit.get_instance_id()

		if not unit.is_death_pending():
			# Реакция предотвращения смерти могла вернуть юнита в ALIVE.
			# Старое смертельное событие больше не должно стать причиной
			# какой-либо последующей смерти этого Runtime.
			_lethal_events_by_unit_id.erase(unit_instance_id)
			continue

		var cause_event := _lethal_events_by_unit_id.get(
			unit_instance_id,
			null
		) as CombatEvent

		if not unit.confirm_death():
			continue

		if unit.cell != null:
			print(
				"DeathResolver: confirmed death and freed cell for ",
				unit.data.unit_name
			)
			unit.cell.remove_unit()

		var death_event := combat_event_log.record_death_event(
			unit,
			cause_event,
			battle_state
		)

		if death_event != null:
			death_events.append(death_event)

		_lethal_events_by_unit_id.erase(unit_instance_id)

	return death_events


func clear() -> void:
	_lethal_events_by_unit_id.clear()
