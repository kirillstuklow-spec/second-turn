extends RefCounted

class_name ReactionSystem


const MAX_REACTION_DEPTH : int = 10


var reaction_queue : ReactionQueue = null

var impact_plan_builder : AbilityImpactPlanBuilder = null


func configure(
	new_reaction_queue : ReactionQueue,
	new_impact_plan_builder : AbilityImpactPlanBuilder
) -> void:
	reaction_queue = new_reaction_queue
	impact_plan_builder = new_impact_plan_builder


func collect_reactions(
	event : CombatEvent,
	battle_state : BattleState
) -> void:
	if (
		event == null
		or battle_state == null
		or reaction_queue == null
	):
		return

	for unit in battle_state.units:
		if unit == null:
			continue

		var effects_at_event : Array[EffectRuntime] = []
		effects_at_event.append_array(unit.active_effects)

		for effect_runtime in effects_at_event:
			_collect_effect_reactions(
				effect_runtime,
				event,
				battle_state
			)


func build_plan(
	task : ReactionTask
) -> ImpactPlanBuildResult:
	if impact_plan_builder == null:
		var missing_builder := ImpactPlanBuildResult.new()
		return missing_builder.reject(
			"ReactionSystem: ImpactPlanBuilder is unavailable"
		)

	return impact_plan_builder.build_triggered(task)


func _collect_effect_reactions(
	effect_runtime : EffectRuntime,
	event : CombatEvent,
	battle_state : BattleState
) -> void:
	if (
		effect_runtime == null
		or effect_runtime.data == null
		or event.reaction_depth >= MAX_REACTION_DEPTH
	):
		return

	for trigger_data in effect_runtime.data.triggers:
		if not _matches_trigger(
			effect_runtime,
			trigger_data,
			event,
			battle_state
		):
			continue

		var task := reaction_queue.enqueue_effect_trigger(
			effect_runtime,
			trigger_data,
			event
		)

		if task == null:
			continue

		effect_runtime.mark_event_processed(
			StringName(trigger_data.trigger_id),
			event.event_id,
			_get_event_activation_serial(event, battle_state),
			_get_event_round_number(event, battle_state)
		)


func _matches_trigger(
	effect_runtime : EffectRuntime,
	trigger_data : EffectTriggerData,
	event : CombatEvent,
	battle_state : BattleState
) -> bool:
	if trigger_data == null or trigger_data.response_plan_data == null:
		return false

	if trigger_data.trigger_id.strip_edges().is_empty():
		return false

	if trigger_data.event_kind != event.kind:
		return false

	if event.applied_amount < trigger_data.minimum_applied_amount:
		return false

	var trigger_id := StringName(trigger_data.trigger_id)

	if effect_runtime.has_processed_event(trigger_id, event.event_id):
		return false

	if (
		trigger_data.ignore_same_effect_runtime
		and event.origin_effect_runtime_id == effect_runtime.runtime_id
	):
		return false

	var event_activation_serial := _get_event_activation_serial(
		event,
		battle_state
	)

	if (
		trigger_data.skip_application_activation
		and event_activation_serial >= 0
		and effect_runtime.last_application_activation_serial
		== event_activation_serial
	):
		return false

	match trigger_data.carrier_relation:
		EffectTriggerData.CarrierRelation.CARRIER_IS_EVENT_TARGET:
			if effect_runtime.carrier != event.target_unit:
				return false

		EffectTriggerData.CarrierRelation.CARRIER_IS_EVENT_SOURCE:
			if effect_runtime.carrier != event.source_unit:
				return false

	var activation_serial := event_activation_serial
	var round_number := _get_event_round_number(event, battle_state)

	match trigger_data.frequency_policy:
		EffectTriggerData.FrequencyPolicy.ONCE_PER_ACTIVATION:
			if (
				effect_runtime.trigger_last_activation_serial.get(
					trigger_id,
					-1
				) == activation_serial
			):
				return false

		EffectTriggerData.FrequencyPolicy.ONCE_PER_ROUND:
			if (
				effect_runtime.trigger_last_round.get(
					trigger_id,
					-1
				) == round_number
			):
				return false

		EffectTriggerData.FrequencyPolicy.ONCE_TOTAL:
			if effect_runtime.triggered_once.has(trigger_id):
				return false

	return true


func _get_event_activation_serial(
	event : CombatEvent,
	battle_state : BattleState
) -> int:
	if event != null and event.activation_serial >= 0:
		return event.activation_serial

	if battle_state == null:
		return -1

	return battle_state.turn_state.activation_serial


func _get_event_round_number(
	event : CombatEvent,
	battle_state : BattleState
) -> int:
	if event != null and event.round_number > 0:
		return event.round_number

	if battle_state == null:
		return 0

	return battle_state.round_number
