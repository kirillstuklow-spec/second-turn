extends Node

class_name CommandDispatcher


var battle_state: BattleState = null
var pipeline_runner: PipelineRunner = null


func configure(
	new_battle_state: BattleState,
	new_pipeline_runner: PipelineRunner
) -> void:
	battle_state = new_battle_state
	pipeline_runner = new_pipeline_runner

	print("CommandDispatcher configured")


func dispatch_command(command: Dictionary) -> void:
	if command.is_empty():
		push_error("CommandDispatcher: empty command")
		return

	if not command.has("type"):
		push_error("CommandDispatcher: command has no type")
		return

	if pipeline_runner == null:
		push_error("CommandDispatcher: pipeline_runner is null")
		return

	var command_type: String = command["type"]

	print("CommandDispatcher received command: ", command_type)

	pipeline_runner.run_command(command)
	
