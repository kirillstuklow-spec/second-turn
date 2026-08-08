extends Node

class_name DecisionPipeline


var battle_state : BattleState = null

var impact_executor : ImpactExecutor = null


func configure(
	new_battle_state : BattleState,
	new_impact_executor : ImpactExecutor
) -> void:
	battle_state = new_battle_state
	impact_executor = new_impact_executor


func select_reaction_target(
	decision_id : StringName,
	target_unit : UnitRuntime
) -> DecisionResolutionResult:
	if battle_state == null or impact_executor == null:
		return DecisionResolutionResult.rejected(
			DecisionResolutionResult.Status.FAILED_EXECUTION,
			"DecisionPipeline не настроен."
		)

	return impact_executor.resolve_pending_decision(
		decision_id,
		target_unit,
		battle_state
	)
