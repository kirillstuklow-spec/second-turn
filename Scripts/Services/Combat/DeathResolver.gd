extends RefCounted

class_name DeathResolver


var _lethal_events_by_unit_id : Dictionary = {}


func observe_combat_event(event : CombatEvent) -> void:
	if (
		event == null
		or event.target_unit == null
		or not event.target_unit.is_death_pending()
		or event.hp_delta >= 0
		or event.kind not in [
			CombatEvent.Kind.DAMAGE_APPLIED,
			CombatEvent.Kind.HEALING_APPLIED
		]
	):
		return

	_lethal_events_by_unit_id[event.target_unit.get_instance_id()] = event


func confirm_pending_deaths(
	battle_state : BattleState,
	combat_event_log : CombatEventLog,
	status_effect_system : StatusEffectSystem = null
) -> Array[CombatEvent]:
	var resolution_events : Array[CombatEvent] = []

	if battle_state == null or combat_event_log == null:
		return resolution_events

	for unit in battle_state.units:
		if unit == null:
			continue

		var unit_instance_id : int = unit.get_instance_id()

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
		var prevention_effect : EffectRuntime = null

		if status_effect_system != null:
			prevention_effect = status_effect_system.try_prevent_death(unit)

		if prevention_effect != null:
			print(
				"DEATH_PREVENTED | unit: ",
				unit.data.unit_name,
				" | effect_id: ",
				prevention_effect.get_effect_id(),
				" | restored HP: ",
				unit.current_hp
			)
			var prevention_event := (
				combat_event_log.record_death_prevented_event(
					unit,
					cause_event,
					prevention_effect,
					battle_state
				)
			)

			if prevention_event != null:
				resolution_events.append(prevention_event)

			_lethal_events_by_unit_id.erase(unit_instance_id)
			continue

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
			resolution_events.append(death_event)

		_lethal_events_by_unit_id.erase(unit_instance_id)

	return resolution_events


func clear() -> void:
	_lethal_events_by_unit_id.clear()
