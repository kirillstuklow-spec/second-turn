extends RefCounted

class_name ReactionSystem


const MAX_REACTION_DEPTH : int = 10


var reaction_queue : ReactionQueue = null

var impact_plan_builder : AbilityImpactPlanBuilder = null

var targeting_service : TargetingService = TargetingService.new()


func configure(
	new_reaction_queue : ReactionQueue,
	new_impact_plan_builder : AbilityImpactPlanBuilder,
	new_targeting_service : TargetingService = null
) -> void:
	reaction_queue = new_reaction_queue
	impact_plan_builder = new_impact_plan_builder

	if new_targeting_service != null:
		targeting_service = new_targeting_service
	elif targeting_service == null:
		targeting_service = TargetingService.new()


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

		var abilities_at_event : Array[UnitAbilityRuntime] = []
		abilities_at_event.append_array(unit.passive_abilities)

		for ability_runtime in abilities_at_event:
			_collect_ability_reactions(
				ability_runtime,
				event
			)

		var effects_at_event : Array[EffectRuntime] = []
		effects_at_event.append_array(unit.active_effects)

		for effect_runtime in effects_at_event:
			_collect_effect_reactions(
				effect_runtime,
				event,
				battle_state
			)


func _collect_ability_reactions(
	ability_runtime : UnitAbilityRuntime,
	event : CombatEvent
) -> void:
	if (
		ability_runtime == null
		or ability_runtime.data == null
		or ability_runtime.data.ability == null
		or event.reaction_depth >= MAX_REACTION_DEPTH
	):
		return

	if (
		ability_runtime.data.ability.activation_mode
		!= AbilityData.ActivationMode.TRIGGERED
	):
		return

	for trigger_data in ability_runtime.data.triggers:
		if not _matches_ability_trigger(
			ability_runtime,
			trigger_data,
			event
		):
			continue

		var task := reaction_queue.enqueue_ability_trigger(
			ability_runtime,
			trigger_data,
			event
		)

		if task == null:
			continue

		ability_runtime.mark_trigger_event_processed(
			StringName(trigger_data.trigger_id),
			event.event_id
		)


func _matches_ability_trigger(
	ability_runtime : UnitAbilityRuntime,
	trigger_data : AbilityTriggerData,
	event : CombatEvent
) -> bool:
	if trigger_data == null or event == null:
		return false

	if ability_runtime.data.impact_plan_data == null:
		return false

	var trigger_id := StringName(trigger_data.trigger_id.strip_edges())

	if trigger_id == &"":
		return false

	if ability_runtime.has_processed_trigger_event(trigger_id, event.event_id):
		return false

	if trigger_data.event_kind != event.kind:
		return false

	if event.applied_amount < trigger_data.minimum_applied_amount:
		return false

	if not trigger_data.accept_reaction_events and event.reaction_depth > 0:
		return false

	if not trigger_data.matches_interaction(event.interaction_type):
		return false

	var source_type_filter := trigger_data.source_type_filter.strip_edges()

	if (
		not source_type_filter.is_empty()
		and event.source_type != StringName(source_type_filter)
	):
		return false

	var owner := ability_runtime.owner

	if owner == null:
		return false

	if trigger_data.require_owner_alive and not owner.is_alive:
		return false

	match trigger_data.owner_relation:
		AbilityTriggerData.OwnerRelation.OWNER_IS_EVENT_TARGET:
			if owner != event.target_unit:
				return false

		AbilityTriggerData.OwnerRelation.OWNER_IS_EVENT_SOURCE:
			if owner != event.source_unit:
				return false

	if (
		trigger_data.require_event_source_alive
		and (
			event.source_unit == null
			or not event.source_unit.is_alive
		)
	):
		return false

	return _matches_event_source_relation(
		owner,
		event.source_unit,
		trigger_data.event_source_relation
	)


func _matches_event_source_relation(
	owner : UnitRuntime,
	event_source : UnitRuntime,
	relation : AbilityTriggerData.EventSourceRelation
) -> bool:
	match relation:
		AbilityTriggerData.EventSourceRelation.ANY:
			return true

		AbilityTriggerData.EventSourceRelation.SELF:
			return event_source == owner

		AbilityTriggerData.EventSourceRelation.ENEMY:
			return (
				event_source != null
				and event_source != owner
				and event_source.team_id != owner.team_id
			)

		AbilityTriggerData.EventSourceRelation.ALLY:
			return (
				event_source != null
				and event_source != owner
				and event_source.team_id == owner.team_id
			)

	return false


func build_plan(
	task : ReactionTask
) -> ImpactPlanBuildResult:
	if impact_plan_builder == null:
		var missing_builder := ImpactPlanBuildResult.new()
		return missing_builder.reject(
			"ReactionSystem: ImpactPlanBuilder is unavailable"
		)

	return impact_plan_builder.build_triggered(task)


func requires_target_decision(task : ReactionTask) -> bool:
	return (
		task != null
		and task.ability_trigger_data != null
		and (
			task.ability_trigger_data.target_selection_policy
			== AbilityTriggerData.TargetSelectionPolicy.PLAYER_CHOICE
		)
		and task.selected_target == null
	)


func create_pending_decision(
	task : ReactionTask,
	battle_state : BattleState
) -> PendingDecision:
	if (
		task == null
		or battle_state == null
		or task.source_ability_runtime == null
		or task.source_ability_data == null
		or targeting_service == null
	):
		return null

	var decision := PendingDecision.new()
	decision.decision_id = StringName(
		"decision_%s" % String(task.reaction_id)
	)
	decision.reason = "Выберите цель для «%s»." % (
		task.source_ability_data.ability_name
	)
	decision.source_unit = task.source_unit
	decision.source_ability_runtime = task.source_ability_runtime
	decision.reaction_task = task
	decision.origin_cell = task.target_origin_cell
	decision.options.append_array(
		targeting_service.get_valid_triggered_target_units(
			battle_state,
			task.source_unit,
			task.target_origin_cell,
			task.source_ability_data
		)
	)
	return decision


func select_pending_decision_target(
	decision : PendingDecision,
	target_unit : UnitRuntime,
	battle_state : BattleState
) -> bool:
	if (
		decision == null
		or decision.reaction_task == null
		or target_unit == null
		or targeting_service == null
	):
		return false

	if not targeting_service.is_valid_triggered_target(
		battle_state,
		decision.source_unit,
		decision.origin_cell,
		decision.source_ability_runtime.data,
		target_unit
	):
		return false

	decision.reaction_task.selected_target = target_unit
	return true


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
