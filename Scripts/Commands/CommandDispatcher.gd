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


func dispatch_command(command: Dictionary) -> Variant:
	if command.is_empty():
		push_error("CommandDispatcher: empty command")
		return null

	if not command.has("type"):
		push_error("CommandDispatcher: command has no type")
		return null

	if pipeline_runner == null:
		push_error("CommandDispatcher: pipeline_runner is null")
		return null

	var command_type: String = command["type"]

	if (
		battle_state != null
		and battle_state.pending_decision != null
		and command_type != "select_decision_target"
	):
		print(
			"CommandDispatcher: command blocked by pending decision: ",
			command_type
		)
		return null

	print("CommandDispatcher received command: ", command_type)

	return pipeline_runner.run_command(command)
	
