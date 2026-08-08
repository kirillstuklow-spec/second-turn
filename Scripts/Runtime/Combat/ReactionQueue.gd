extends RefCounted

class_name ReactionQueue


var tasks : Array[ReactionTask] = []

var _next_reaction_sequence : int = 1


func enqueue_effect_trigger(
	effect_runtime : EffectRuntime,
	trigger_data : EffectTriggerData,
	event : CombatEvent
) -> ReactionTask:
	if (
		effect_runtime == null
		or trigger_data == null
		or event == null
	):
		return null

	var task := ReactionTask.new()
	task.reaction_id = StringName(
		"reaction_%06d" % _next_reaction_sequence
	)
	task.execution_id = StringName(
		"reaction_execution_%06d" % _next_reaction_sequence
	)
	task.root_execution_id = event.root_execution_id
	task.reaction_depth = event.reaction_depth + 1
	task.trigger_event = event
	task.trigger_data = trigger_data
	task.response_plan_data = trigger_data.response_plan_data
	task.source_effect_runtime = effect_runtime
	task.source_effect_runtime_id = effect_runtime.runtime_id
	task.source_effect_data = effect_runtime.data
	task.source_unit = effect_runtime.source_unit
	task.source_ability_data = effect_runtime.source_ability_data
	task.carrier = effect_runtime.carrier as UnitRuntime

	_next_reaction_sequence += 1
	tasks.append(task)
	return task


func enqueue_ability_trigger(
	ability_runtime : UnitAbilityRuntime,
	trigger_data : AbilityTriggerData,
	event : CombatEvent
) -> ReactionTask:
	if (
		ability_runtime == null
		or ability_runtime.data == null
		or ability_runtime.owner == null
		or trigger_data == null
		or event == null
	):
		return null

	var task := ReactionTask.new()
	task.reaction_id = StringName(
		"reaction_%06d" % _next_reaction_sequence
	)
	task.execution_id = StringName(
		"reaction_execution_%06d" % _next_reaction_sequence
	)
	task.root_execution_id = event.root_execution_id
	task.reaction_depth = event.reaction_depth + 1
	task.trigger_event = event
	task.ability_trigger_data = trigger_data
	task.response_plan_data = ability_runtime.data.impact_plan_data
	task.source_ability_runtime = ability_runtime
	task.source_unit = ability_runtime.owner
	task.source_ability_data = ability_runtime.data
	task.carrier = ability_runtime.owner

	if ability_runtime.owner == event.target_unit:
		task.target_origin_cell = event.target_cell
	elif ability_runtime.owner == event.source_unit:
		task.target_origin_cell = event.source_cell
	else:
		task.target_origin_cell = ability_runtime.owner.cell

	_next_reaction_sequence += 1
	tasks.append(task)
	return task


func pop_front() -> ReactionTask:
	if tasks.is_empty():
		return null

	return tasks.pop_front()


func has_pending() -> bool:
	return not tasks.is_empty()


func clear() -> void:
	tasks.clear()
	_next_reaction_sequence = 1
