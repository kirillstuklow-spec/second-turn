extends Node

class_name AbilityPipeline


const ALGORITHM_DEAL_DAMAGE : StringName = (
	AbilityAlgorithmRegistry.ALGORITHM_DEAL_DAMAGE
)
const ALGORITHM_HEAL_TARGET : StringName = (
	AbilityAlgorithmRegistry.ALGORITHM_HEAL_TARGET
)

const PARAM_DAMAGE : StringName = AbilityAlgorithmRegistry.PARAM_DAMAGE
const PARAM_HEAL : StringName = AbilityAlgorithmRegistry.PARAM_HEAL
const PARAM_ARMOR_PENETRATION : StringName = (
	AbilityAlgorithmRegistry.PARAM_ARMOR_PENETRATION
)
const PARAM_KEYWORD : StringName = AbilityAlgorithmRegistry.PARAM_KEYWORD
const PARAM_RADIUS : StringName = AbilityAlgorithmRegistry.PARAM_RADIUS

# Совместимый публичный ID для существующих тестов и журналов RNG.
const RNG_PURPOSE_ARMOR_BLOCK : StringName = (
	InteractionResolver.RNG_PURPOSE_ARMOR_BLOCK
)


var battle_state : BattleState = null

var availability_service : AbilityAvailabilityService = null

var algorithm_registry : AbilityAlgorithmRegistry = null

var targeting_service : TargetingService = null

var impact_plan_builder : AbilityImpactPlanBuilder = null

var impact_executor : ImpactExecutor = null

var _next_execution_sequence : int = 1


func configure(
	new_battle_state : BattleState,
	new_availability_service : AbilityAvailabilityService,
	new_algorithm_registry : AbilityAlgorithmRegistry = null,
	new_targeting_service : TargetingService = null,
	new_impact_plan_builder : AbilityImpactPlanBuilder = null,
	new_impact_executor : ImpactExecutor = null
) -> void:
	battle_state = new_battle_state
	availability_service = new_availability_service
	algorithm_registry = new_algorithm_registry
	targeting_service = new_targeting_service
	impact_plan_builder = new_impact_plan_builder
	impact_executor = new_impact_executor

	if algorithm_registry == null:
		algorithm_registry = AbilityAlgorithmRegistry.new()

	if availability_service != null:
		availability_service.set_algorithm_registry(
			algorithm_registry
		)

	if targeting_service == null:
		targeting_service = TargetingService.new()

	if impact_plan_builder == null:
		impact_plan_builder = AbilityImpactPlanBuilder.new()

	if impact_executor == null:
		impact_executor = ImpactExecutor.new()

	_next_execution_sequence = 1

	print("AbilityPipeline configured")


func execute_ability(
	source_unit : UnitRuntime,
	target_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	target_cell : CellRuntime = null
) -> AbilityExecutionResult:
	var input_error := _get_input_error(
		source_unit,
		ability_runtime
	)

	if not input_error.is_empty():
		return _reject(
			AbilityExecutionResult.Status.REJECTED_INPUT,
			input_error,
			true
		)

	var schema_result := algorithm_registry.validate_unit_ability(
		ability_runtime.data
	)

	if not schema_result.is_valid:
		return _reject(
			AbilityExecutionResult.Status.REJECTED_SCHEMA,
			"Некорректная схема способности:\n"
			+ schema_result.get_summary(),
			true
		)

	var availability := availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	if not availability.is_available:
		return _reject(
			AbilityExecutionResult.Status.REJECTED_AVAILABILITY,
			availability.get_summary()
		)

	var targeting_result := targeting_service.resolve(
		battle_state,
		source_unit,
		target_unit,
		target_cell,
		ability_runtime.data,
		schema_result.resolved_parameters
	)

	if not targeting_result.is_valid:
		var rejected_target := _reject(
			AbilityExecutionResult.Status.REJECTED_TARGET,
			targeting_result.get_summary()
		)
		rejected_target.targeting_result = targeting_result
		return rejected_target

	var execution_id := _peek_execution_id()
	var hp_before_commit := source_unit.current_hp
	var build_result := impact_plan_builder.build(
		execution_id,
		source_unit,
		ability_runtime,
		targeting_result,
		schema_result.resolved_parameters
	)

	if not build_result.is_valid or build_result.plan == null:
		var rejected_plan := _reject(
			AbilityExecutionResult.Status.REJECTED_PLAN,
			build_result.message,
			true
		)
		rejected_plan.execution_id = execution_id
		rejected_plan.targeting_result = targeting_result
		return rejected_plan

	var plan_issues := impact_executor.validate_plan(
		build_result.plan,
		targeting_result.snapshot,
		battle_state
	)

	if not plan_issues.is_empty():
		var rejected_validation := _reject(
			AbilityExecutionResult.Status.REJECTED_PLAN,
			"\n".join(plan_issues),
			true
		)
		rejected_validation.execution_id = execution_id
		rejected_validation.targeting_result = targeting_result
		rejected_validation.impact_plan = build_result.plan
		return rejected_validation

	if not _commit_costs(
		source_unit,
		ability_runtime,
		execution_id
	):
		var failed_commit := _reject(
			AbilityExecutionResult.Status.FAILED_COMMIT,
			"Не удалось зафиксировать стоимость способности.",
			true
		)
		failed_commit.execution_id = execution_id
		failed_commit.targeting_result = targeting_result
		failed_commit.impact_plan = build_result.plan
		return failed_commit

	_next_execution_sequence += 1

	impact_executor.collect_health_point_cost_event(
		source_unit,
		ability_runtime.data,
		execution_id,
		hp_before_commit,
		source_unit.current_hp,
		battle_state
	)

	print("")
	print("========================================")
	print(
		source_unit.data.unit_name,
		" uses ",
		ability_runtime.data.ability_name,
		" | execution: ",
		execution_id,
		" | targets: ",
		targeting_result.target_unit_snapshots.size()
	)

	var execution_result := impact_executor.execute(
		build_result.plan,
		targeting_result.snapshot,
		battle_state
	)

	if not execution_result.is_successful():
		var failed_execution := _reject(
			AbilityExecutionResult.Status.FAILED_EXECUTION,
			execution_result.get_summary(),
			true
		)
		failed_execution.execution_id = execution_id
		failed_execution.targeting_result = targeting_result
		failed_execution.impact_plan = build_result.plan
		failed_execution.impact_execution_result = execution_result
		return failed_execution

	print("========================================")

	return AbilityExecutionResult.committed(
		execution_id,
		targeting_result,
		build_result.plan,
		execution_result
	)


func _get_input_error(
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime
) -> String:
	if battle_state == null:
		return "AbilityPipeline: battle_state is null"

	if source_unit == null:
		return "AbilityPipeline: source_unit is null"

	if ability_runtime == null:
		return "AbilityPipeline: ability_runtime is null"

	if ability_runtime.data == null:
		return "AbilityPipeline: ability data is null"

	if ability_runtime.owner != source_unit:
		return (
			"AbilityPipeline: source_unit is not "
			+ "the ability runtime owner"
		)

	if availability_service == null:
		return "AbilityPipeline: availability_service is null"

	if algorithm_registry == null:
		return "AbilityPipeline: algorithm_registry is null"

	if targeting_service == null:
		return "AbilityPipeline: targeting_service is null"

	if impact_plan_builder == null:
		return "AbilityPipeline: impact_plan_builder is null"

	if impact_executor == null:
		return "AbilityPipeline: impact_executor is null"

	return ""


func _commit_costs(
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	execution_id : StringName
) -> bool:
	var action_point_cost := ability_runtime.data.action_point_cost
	var health_point_cost := ability_runtime.data.health_point_cost

	if not source_unit.can_spend_action_points(action_point_cost):
		return false

	if not source_unit.can_spend_health_points(health_point_cost):
		return false

	if not source_unit.spend_action_points(action_point_cost):
		return false

	if not source_unit.spend_health_points(health_point_cost):
		source_unit.action_points_remaining += action_point_cost
		return false

	if ability_runtime.record_use(
		execution_id,
		ability_runtime.current_round_number,
		ability_runtime.current_activation_index
	):
		return true

	# record_use не меняет Runtime при отказе, поэтому возвращаем обе уже
	# списанные цены без создания игровых событий.
	source_unit.action_points_remaining += action_point_cost
	source_unit.refund_health_point_cost(health_point_cost)
	return false


func _peek_execution_id() -> StringName:
	return StringName(
		"ability_execution_%06d" % _next_execution_sequence
	)


func _reject(
	status : AbilityExecutionResult.Status,
	message : String,
	as_error : bool = false
) -> AbilityExecutionResult:
	var full_message := "AbilityPipeline: " + message

	if as_error:
		push_error(full_message)
	else:
		print(full_message)

	return AbilityExecutionResult.rejected(status, message)
