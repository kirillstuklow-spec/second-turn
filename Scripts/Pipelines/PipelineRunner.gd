extends Node
class_name PipelineRunner


var ability_pipeline: AbilityPipeline = null
var movement_pipeline: MovementPipeline = null
var turn_pipeline: TurnPipeline = null
var decision_pipeline: DecisionPipeline = null
var event_queue: EventQueue = null


func configure(
	new_ability_pipeline: AbilityPipeline,
	new_movement_pipeline: MovementPipeline,
	new_turn_pipeline: TurnPipeline,
	new_event_queue: EventQueue,
	new_decision_pipeline: DecisionPipeline = null
) -> void:
	ability_pipeline = new_ability_pipeline
	movement_pipeline = new_movement_pipeline
	turn_pipeline = new_turn_pipeline
	event_queue = new_event_queue
	decision_pipeline = new_decision_pipeline

	print("PipelineRunner configured")


func run_command(command: Dictionary) -> Variant:
	if command.is_empty():
		push_error("PipelineRunner: empty command")
		return null

	if not command.has("type"):
		push_error("PipelineRunner: command has no type")
		return null

	var command_type: String = command["type"]

	print("PipelineRunner received command: ", command_type)

	_push_event({
		"type": "CommandStarted",
		"command_type": command_type
	})

	var command_result : Variant = null

	match command_type:
		"use_ability":
			command_result = _run_use_ability(command)

		"move_unit":
			command_result = _run_move_unit(command)

		"end_turn":
			_run_end_turn()

		"select_decision_target":
			command_result = _run_select_decision_target(command)

		_:
			push_error(
				"PipelineRunner: unknown command type: "
				+ command_type
			)

	_push_event({
		"type": "CommandFinished",
		"command_type": command_type
	})

	return command_result


func _run_use_ability(
	command: Dictionary
) -> AbilityExecutionResult:
	if ability_pipeline == null:
		push_error("PipelineRunner: ability_pipeline is null")
		return AbilityExecutionResult.rejected(
			AbilityExecutionResult.Status.REJECTED_INPUT,
			"PipelineRunner: ability_pipeline is null"
		)

	var source_unit: UnitRuntime = command.get(
		"source_unit",
		null
	)

	var target_unit: UnitRuntime = command.get(
		"target_unit",
		null
	)

	var target_cell: CellRuntime = command.get(
		"target_cell",
		null
	)

	var ability_runtime: UnitAbilityRuntime = command.get(
		"ability_runtime",
		null
	)

	return ability_pipeline.execute_ability(
		source_unit,
		target_unit,
		ability_runtime,
		target_cell
	)


func _run_move_unit(command: Dictionary) -> bool:
	if movement_pipeline == null:
		push_error("PipelineRunner: movement_pipeline is null")
		return false

	if not command.has("unit"):
		push_error(
			"PipelineRunner: move_unit command has no unit"
		)
		return false

	if not command.has("target_cell"):
		push_error(
			"PipelineRunner: move_unit command has no target_cell"
		)
		return false

	var unit: UnitRuntime = command["unit"]
	var target_cell: CellRuntime = command["target_cell"]

	return movement_pipeline.execute_move(
		unit,
		target_cell
	)


func _run_end_turn() -> void:
	if turn_pipeline == null:
		push_error("PipelineRunner: turn_pipeline is null")
		return

	turn_pipeline.end_current_activation()


func _run_select_decision_target(
	command : Dictionary
) -> DecisionResolutionResult:
	if decision_pipeline == null:
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.FAILED_EXECUTION,
			"PipelineRunner: decision_pipeline is null"
		)

	var decision_id := StringName(command.get("decision_id", &""))
	var target_unit := command.get("target_unit", null) as UnitRuntime
	var result := decision_pipeline.select_reaction_target(
		decision_id,
		target_unit
	)

	if (
		result.was_resolved()
		and turn_pipeline != null
		and turn_pipeline.battle_state != null
		and turn_pipeline.battle_state.pending_decision == null
	):
		turn_pipeline.resume_after_pending_decision()

	return result


func _push_event(event: Dictionary) -> void:
	if event_queue == null:
		return

	event_queue.push_event(event)
