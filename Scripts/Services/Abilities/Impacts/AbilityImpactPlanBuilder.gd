extends RefCounted

class_name AbilityImpactPlanBuilder


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


func build(
	execution_id : StringName,
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	targeting_result : TargetingResult,
	resolved_parameters : Dictionary
) -> ImpactPlanBuildResult:
	var result := ImpactPlanBuildResult.new()

	if execution_id == &"":
		return result.reject(
			"ImpactPlanBuilder: execution_id is empty"
		)

	if source_unit == null:
		return result.reject(
			"ImpactPlanBuilder: source_unit is null"
		)

	if (
		ability_runtime == null
		or ability_runtime.data == null
		or ability_runtime.data.ability == null
	):
		return result.reject(
			"ImpactPlanBuilder: ability data is missing"
		)

	if targeting_result == null or not targeting_result.is_valid:
		return result.reject(
			"ImpactPlanBuilder: targeting result is invalid"
		)

	var ability_data := ability_runtime.data.ability
	var topology := ImpactPlan.Topology.TREE

	if (
		ability_data.impact_plan_type
		== AbilityData.ImpactPlanType.QUEUE
	):
		topology = ImpactPlan.Topology.QUEUE

	var plan := ImpactPlan.create(execution_id, topology)
	var algorithm_id := StringName(ability_data.algorithm_id)
	var operation := Impact.Operation.DAMAGE
	var magnitude := 0
	var armor_penetration := 0
	var source_type : StringName = &""

	match algorithm_id:
		ALGORITHM_DEAL_DAMAGE:
			operation = Impact.Operation.DAMAGE
			magnitude = int(
				resolved_parameters.get(PARAM_DAMAGE, 0)
			)
			armor_penetration = int(
				resolved_parameters.get(PARAM_ARMOR_PENETRATION, 0)
			)
			source_type = StringName(str(
				resolved_parameters.get(PARAM_KEYWORD, "")
			))

		ALGORITHM_HEAL_TARGET:
			operation = Impact.Operation.HEAL
			magnitude = int(
				resolved_parameters.get(PARAM_HEAL, 0)
			)

		_:
			return result.reject(
				"ImpactPlanBuilder: unsupported algorithm_id '%s'"
				% ability_data.algorithm_id
			)

	var interaction_type := Impact.interaction_type_from_ability(
		ability_data
	)
	var impact_index := 0

	for target_snapshot in targeting_result.target_unit_snapshots:
		if target_snapshot == null or target_snapshot.unit == null:
			return result.reject(
				"ImpactPlanBuilder: target snapshot is invalid"
			)

		var impact_id := StringName(
			"%s_impact_%03d" % [execution_id, impact_index + 1]
		)
		var impact := Impact.create(
			impact_id,
			execution_id,
			source_unit,
			target_snapshot.unit,
			target_snapshot.cell,
			operation,
			interaction_type,
			source_type,
			magnitude,
			armor_penetration
		)
		impact.order_index = impact_index
		impact.metadata = {
			"primary": true,
			"target_key": target_snapshot.get_stable_key()
		}

		var was_added := false

		if topology == ImpactPlan.Topology.QUEUE:
			was_added = plan.append_queue_impact(impact)
		else:
			was_added = plan.add_root_impact(impact)

		if not was_added:
			return result.reject(
				"ImpactPlanBuilder: impact could not be added"
			)

		impact_index += 1

	if plan.impacts.is_empty():
		return result.reject(
			"ImpactPlanBuilder: plan has no impacts"
		)

	result.plan = plan
	return result
