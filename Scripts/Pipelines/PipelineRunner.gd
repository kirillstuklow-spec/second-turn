extends Node

class_name PipelineRunner


var ability_pipeline: AbilityPipeline = null
var movement_pipeline: MovementPipeline = null
var event_queue: EventQueue = null


func configure(
	new_ability_pipeline: AbilityPipeline,
	new_movement_pipeline: MovementPipeline,
	new_event_queue: EventQueue
) -> void:
	ability_pipeline = new_ability_pipeline
	movement_pipeline = new_movement_pipeline
	event_queue = new_event_queue

	print("PipelineRunner configured")


func run_command(command: Dictionary) -> void:
	if command.is_empty():
		push_error("PipelineRunner: empty command")
		return

	if not command.has("type"):
		push_error("PipelineRunner: command has no type")
		return

	var command_type: String = command["type"]

	print("PipelineRunner received command: ", command_type)

	_push_event({
		"type": "CommandStarted",
		"command_type": command_type
	})

	match command_type:
		"use_ability":
			_run_use_ability(command)
		"move_unit":
			_run_move_unit(command)

		_:
			push_error("PipelineRunner: unknown command type: " + command_type)

	_push_event({
		"type": "CommandFinished",
		"command_type": command_type
	})


func _run_use_ability(command : Dictionary) -> void:
	if ability_pipeline == null:
		push_error("PipelineRunner: ability_pipeline is null")
		return

	var source_unit : UnitRuntime = command.get("source_unit", null)
	var target_unit : UnitRuntime = command.get("target_unit", null)
	var target_cell : CellRuntime = command.get("target_cell", null)
	var unit_ability : UnitAbilityData = command.get("unit_ability", null)

	if source_unit == null:
		push_error("PipelineRunner: source_unit is null")
		return

	if unit_ability == null:
		push_error("PipelineRunner: unit_ability is null")
		return

	ability_pipeline.execute_ability(
		source_unit,
		target_unit,
		unit_ability,
		target_cell
	)

func _run_move_unit(command: Dictionary) -> void:
	if movement_pipeline == null:
		push_error("PipelineRunner: movement_pipeline is null")
		return

	if not command.has("unit"):
		push_error("PipelineRunner: move_unit command has no unit")
		return

	if not command.has("target_cell"):
		push_error("PipelineRunner: move_unit command has no target_cell")
		return

	var unit: UnitRuntime = command["unit"]
	var target_cell: CellRuntime = command["target_cell"]

	movement_pipeline.execute_move(
		unit,
		target_cell
	)

func _push_event(event: Dictionary) -> void:
	if event_queue == null:
		return

	event_queue.push_event(event)
