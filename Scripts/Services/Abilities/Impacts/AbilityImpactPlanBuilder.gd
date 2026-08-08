extends RefCounted

class_name AbilityImpactPlanBuilder


const ALGORITHM_DEAL_DAMAGE : StringName = (
	AbilityAlgorithmRegistry.ALGORITHM_DEAL_DAMAGE
)
const ALGORITHM_HEAL_TARGET : StringName = (
	AbilityAlgorithmRegistry.ALGORITHM_HEAL_TARGET
)
const ALGORITHM_EXECUTE_IMPACT_PLAN : StringName = (
	AbilityAlgorithmRegistry.ALGORITHM_EXECUTE_IMPACT_PLAN
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
	var input_error := _get_active_build_error(
		execution_id,
		source_unit,
		ability_runtime,
		targeting_result
	)

	if not input_error.is_empty():
		var rejected := ImpactPlanBuildResult.new()
		return rejected.reject(input_error)

	var algorithm_id := StringName(
		ability_runtime.data.ability.algorithm_id
	)

	if algorithm_id == ALGORITHM_EXECUTE_IMPACT_PLAN:
		return _build_declarative_ability(
			execution_id,
			source_unit,
			ability_runtime,
			targeting_result
		)

	return _build_legacy_algorithm(
		execution_id,
		source_unit,
		ability_runtime,
		targeting_result,
		resolved_parameters,
		algorithm_id
	)


func build_triggered(
	task : ReactionTask
) -> ImpactPlanBuildResult:
	var result := ImpactPlanBuildResult.new()

	if task == null:
		return result.reject("ImpactPlanBuilder: reaction task is null")

	if task.execution_id == &"":
		return result.reject(
			"ImpactPlanBuilder: reaction execution_id is empty"
		)

	if task.response_plan_data == null:
		return result.reject(
			"ImpactPlanBuilder: reaction plan data is missing"
		)

	var plan_issues := ImpactPlanDataValidator.validate(
		task.response_plan_data
	)

	if not plan_issues.is_empty():
		return result.reject(
			"ImpactPlanBuilder: invalid reaction plan: "
			+ " | ".join(plan_issues)
		)

	var selected_target := task.carrier
	var target_key := "reaction_carrier"

	if task.source_ability_runtime != null:
		if task.trigger_event == null:
			return result.reject(
				"ImpactPlanBuilder: triggered ability has no event"
			)

		if task.selected_target != null:
			selected_target = task.selected_target
			target_key = "reaction_player_choice"
		else:
			selected_target = task.trigger_event.source_unit
			target_key = "reaction_event_source"

	var context := {
		"ability_source": task.source_unit,
		"selected_target": selected_target,
		"selected_cell": (
			selected_target.cell if selected_target != null else null
		),
		"event": task.trigger_event,
		"effect_runtime": task.source_effect_runtime,
		"source_object": task,
		"effect_source": task.source_unit,
		"effect_carrier": task.carrier,
		"source_ability_data": task.source_ability_data,
		"root_execution_id": task.root_execution_id,
		"reaction_depth": task.reaction_depth,
		"origin_effect_runtime_id": task.source_effect_runtime_id,
		"target_key": target_key,
		"is_primary": false
	}
	var contexts : Array[Dictionary] = [context]

	return _build_from_plan_data(
		task.execution_id,
		task.response_plan_data,
		contexts
	)


func _build_declarative_ability(
	execution_id : StringName,
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	targeting_result : TargetingResult
) -> ImpactPlanBuildResult:
	var result := ImpactPlanBuildResult.new()
	var plan_data := ability_runtime.data.impact_plan_data

	if plan_data == null:
		return result.reject(
			"ImpactPlanBuilder: ImpactPlanData is missing"
		)

	var plan_issues := ImpactPlanDataValidator.validate(plan_data)

	if not plan_issues.is_empty():
		return result.reject(
			"ImpactPlanBuilder: invalid ImpactPlanData: "
			+ " | ".join(plan_issues)
		)

	var contexts : Array[Dictionary] = []

	for target_snapshot in targeting_result.target_unit_snapshots:
		if target_snapshot == null or target_snapshot.unit == null:
			return result.reject(
				"ImpactPlanBuilder: target snapshot is invalid"
			)

		contexts.append({
			"ability_source": source_unit,
			"selected_target": target_snapshot.unit,
			"selected_cell": target_snapshot.cell,
			"event": null,
			"effect_runtime": null,
			"effect_source": null,
			"effect_carrier": null,
			"source_ability_data": ability_runtime.data,
			"root_execution_id": execution_id,
			"reaction_depth": 0,
			"origin_effect_runtime_id": &"",
			"target_key": target_snapshot.get_stable_key(),
			"is_primary": true
		})

	if contexts.is_empty() and targeting_result.selected_cell_snapshot != null:
		contexts.append({
			"ability_source": source_unit,
			"selected_target": null,
			"selected_cell": targeting_result.selected_cell_snapshot.cell,
			"event": null,
			"effect_runtime": null,
			"effect_source": null,
			"effect_carrier": null,
			"source_ability_data": ability_runtime.data,
			"root_execution_id": execution_id,
			"reaction_depth": 0,
			"origin_effect_runtime_id": &"",
			"target_key": (
				targeting_result.selected_cell_snapshot.get_stable_key()
			),
			"is_primary": true
		})

	if contexts.is_empty():
		return result.reject(
			"ImpactPlanBuilder: declarative plan has no context"
		)

	return _build_from_plan_data(execution_id, plan_data, contexts)


func _build_from_plan_data(
	execution_id : StringName,
	plan_data : ImpactPlanData,
	contexts : Array[Dictionary]
) -> ImpactPlanBuildResult:
	var result := ImpactPlanBuildResult.new()
	var topology := ImpactPlan.Topology.TREE

	if plan_data.topology == ImpactPlanData.Topology.QUEUE:
		topology = ImpactPlan.Topology.QUEUE

	var plan := ImpactPlan.create(execution_id, topology)
	var order_offset := 0

	for context_index in range(contexts.size()):
		var append_error := _append_context_nodes(
			plan,
			plan_data,
			contexts[context_index],
			context_index,
			order_offset
		)

		if not append_error.is_empty():
			return result.reject(append_error)

		order_offset += plan_data.nodes.size()

	if plan.impacts.is_empty():
		return result.reject("ImpactPlanBuilder: plan has no impacts")

	result.plan = plan
	return result


func _append_context_nodes(
	plan : ImpactPlan,
	plan_data : ImpactPlanData,
	context : Dictionary,
	context_index : int,
	order_offset : int
) -> String:
	var impacts_by_node_id : Dictionary = {}
	var runtime_ids_by_node_id : Dictionary = {}
	var context_token := "t%03d" % (context_index + 1)

	for node_index in range(plan_data.nodes.size()):
		var node : ImpactNodeData = plan_data.nodes[node_index]
		var runtime_id := StringName(
			"%s_%s_%s" % [
				plan.execution_id,
				context_token,
				node.node_id
			]
		)
		var source_unit := _resolve_source_unit(node, context)
		var target_unit := _resolve_target_unit(node, context)
		var magnitude_result := MagnitudeResolver.resolve_node_magnitude(
			node,
			context.get("event", null) as CombatEvent
		)

		if source_unit == null:
			return (
				"ImpactPlanBuilder: source for node '%s' is unavailable"
				% node.node_id
			)

		if target_unit == null and node.operation != Impact.Operation.SUMMON:
			return (
				"ImpactPlanBuilder: target for node '%s' is unavailable"
				% node.node_id
			)

		if (
			node.operation in [Impact.Operation.DAMAGE, Impact.Operation.HEAL]
			and not bool(magnitude_result.get("is_valid", false))
		):
			return str(magnitude_result.get(
				"message",
				"ImpactPlanBuilder: magnitude could not be resolved"
			))

		var resolved_magnitude := node.magnitude

		if node.operation in [Impact.Operation.DAMAGE, Impact.Operation.HEAL]:
			resolved_magnitude = int(magnitude_result.get("value", 0))

		var target_cell : CellRuntime = context.get("selected_cell", null)

		if target_unit != null:
			target_cell = target_unit.cell

		var impact := Impact.create(
			runtime_id,
			plan.execution_id,
			source_unit,
			target_unit,
			target_cell,
			node.operation,
			node.interaction_type,
			StringName(node.source_type),
			resolved_magnitude,
			node.armor_penetration
		)
		impact.source_object = _resolve_source_object(node, context, source_unit)
		impact.source_ability_data = context.get(
			"source_ability_data",
			null
		) as UnitAbilityData
		impact.root_execution_id = StringName(context.get(
			"root_execution_id",
			plan.execution_id
		))
		impact.reaction_depth = int(context.get("reaction_depth", 0))
		impact.origin_effect_runtime_id = StringName(context.get(
			"origin_effect_runtime_id",
			&""
		))
		impact.healing_kind = node.healing_kind
		impact.effect_data = node.effect_data
		impact.summon_unit_data = node.summon_unit_data
		impact.transition_condition = node.transition_condition
		impact.order_index = order_offset + node_index
		impact.metadata = node.metadata.duplicate(true)
		impact.metadata["plan_data_node_id"] = node.node_id
		impact.metadata["target_key"] = context.get("target_key", "")
		impact.metadata["primary"] = (
			bool(context.get("is_primary", false))
			and node.parent_node_id.is_empty()
		)

		impacts_by_node_id[node.node_id] = impact
		runtime_ids_by_node_id[node.node_id] = runtime_id

	if plan.topology == ImpactPlan.Topology.QUEUE:
		for node in plan_data.nodes:
			if not plan.append_queue_impact(impacts_by_node_id[node.node_id]):
				return "ImpactPlanBuilder: queue node could not be added"

		return ""

	var pending_node_ids : Array[String] = []

	for node in plan_data.nodes:
		if node.parent_node_id.is_empty():
			if not plan.add_root_impact(impacts_by_node_id[node.node_id]):
				return "ImpactPlanBuilder: root node could not be added"
		else:
			pending_node_ids.append(node.node_id)

	while not pending_node_ids.is_empty():
		var progress_was_made := false
		var pending_copy := pending_node_ids.duplicate()

		for node_id in pending_copy:
			var node := _get_node_data(plan_data, node_id)

			if node == null:
				return "ImpactPlanBuilder: node data disappeared"

			var parent_runtime_id : StringName = runtime_ids_by_node_id.get(
				node.parent_node_id,
				&""
			)

			if parent_runtime_id == &"" or plan.get_impact(parent_runtime_id) == null:
				continue

			if not plan.add_child_impact(
				parent_runtime_id,
				impacts_by_node_id[node_id]
			):
				return "ImpactPlanBuilder: child node could not be added"

			pending_node_ids.erase(node_id)
			progress_was_made = true

		if not progress_was_made:
			return "ImpactPlanBuilder: unresolved parent dependency"

	return ""


func _resolve_source_unit(
	node : ImpactNodeData,
	context : Dictionary
) -> UnitRuntime:
	var event := context.get("event", null) as CombatEvent

	match node.source_reference:
		ImpactNodeData.SourceReference.ABILITY_SOURCE:
			return context.get("ability_source", null) as UnitRuntime

		ImpactNodeData.SourceReference.EFFECT_SOURCE:
			return context.get("effect_source", null) as UnitRuntime

		ImpactNodeData.SourceReference.EVENT_SOURCE:
			return event.source_unit if event != null else null

		ImpactNodeData.SourceReference.EFFECT_CARRIER:
			return context.get("effect_carrier", null) as UnitRuntime

	return null


func _resolve_source_object(
	node : ImpactNodeData,
	context : Dictionary,
	source_unit : UnitRuntime
) -> Variant:
	if node.source_reference == ImpactNodeData.SourceReference.EFFECT_SOURCE:
		var effect_source_object : Variant = context.get(
			"source_object",
			context.get("effect_runtime", null)
		)

		if effect_source_object != null:
			return effect_source_object

	return source_unit


func _resolve_target_unit(
	node : ImpactNodeData,
	context : Dictionary
) -> UnitRuntime:
	var event := context.get("event", null) as CombatEvent

	match node.target_reference:
		ImpactNodeData.TargetReference.SELECTED_TARGET:
			return context.get("selected_target", null) as UnitRuntime

		ImpactNodeData.TargetReference.ABILITY_SOURCE:
			return context.get("ability_source", null) as UnitRuntime

		ImpactNodeData.TargetReference.EFFECT_CARRIER:
			return context.get("effect_carrier", null) as UnitRuntime

		ImpactNodeData.TargetReference.EVENT_SOURCE:
			return event.source_unit if event != null else null

		ImpactNodeData.TargetReference.EVENT_TARGET:
			return event.target_unit if event != null else null

	return null


func _get_node_data(
	plan_data : ImpactPlanData,
	node_id : String
) -> ImpactNodeData:
	for node in plan_data.nodes:
		if node != null and node.node_id == node_id:
			return node

	return null


func _build_legacy_algorithm(
	execution_id : StringName,
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	targeting_result : TargetingResult,
	resolved_parameters : Dictionary,
	algorithm_id : StringName
) -> ImpactPlanBuildResult:
	var result := ImpactPlanBuildResult.new()
	var ability_data := ability_runtime.data.ability
	var topology := ImpactPlan.Topology.TREE

	if ability_data.impact_plan_type == AbilityData.ImpactPlanType.QUEUE:
		topology = ImpactPlan.Topology.QUEUE

	var plan := ImpactPlan.create(execution_id, topology)
	var operation := Impact.Operation.DAMAGE
	var magnitude := 0
	var armor_penetration := 0
	var source_type := StringName(str(
		resolved_parameters.get(PARAM_KEYWORD, "")
	))

	match algorithm_id:
		ALGORITHM_DEAL_DAMAGE:
			operation = Impact.Operation.DAMAGE
			magnitude = int(resolved_parameters.get(PARAM_DAMAGE, 0))
			armor_penetration = int(
				resolved_parameters.get(PARAM_ARMOR_PENETRATION, 0)
			)

		ALGORITHM_HEAL_TARGET:
			operation = Impact.Operation.HEAL
			magnitude = int(resolved_parameters.get(PARAM_HEAL, 0))

		_:
			return result.reject(
				"ImpactPlanBuilder: unsupported algorithm_id '%s'"
				% ability_data.algorithm_id
			)

	var interaction_type := Impact.interaction_type_from_ability(ability_data)
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
		impact.source_ability_data = ability_runtime.data
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
		return result.reject("ImpactPlanBuilder: plan has no impacts")

	result.plan = plan
	return result


func _get_active_build_error(
	execution_id : StringName,
	source_unit : UnitRuntime,
	ability_runtime : UnitAbilityRuntime,
	targeting_result : TargetingResult
) -> String:
	if execution_id == &"":
		return "ImpactPlanBuilder: execution_id is empty"

	if source_unit == null:
		return "ImpactPlanBuilder: source_unit is null"

	if (
		ability_runtime == null
		or ability_runtime.data == null
		or ability_runtime.data.ability == null
	):
		return "ImpactPlanBuilder: ability data is missing"

	if targeting_result == null or not targeting_result.is_valid:
		return "ImpactPlanBuilder: targeting result is invalid"

	return ""
