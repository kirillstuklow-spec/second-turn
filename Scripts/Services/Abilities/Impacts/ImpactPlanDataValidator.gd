extends RefCounted

class_name ImpactPlanDataValidator


static func validate(plan_data : ImpactPlanData) -> PackedStringArray:
	return _validate_plan(plan_data, {}, {})


static func _validate_plan(
	plan_data : ImpactPlanData,
	visited_plans : Dictionary,
	visited_effects : Dictionary
) -> PackedStringArray:
	var issues := PackedStringArray()

	if plan_data == null:
		issues.append("ImpactPlanData отсутствует.")
		return issues

	var plan_key := plan_data.get_instance_id()

	if visited_plans.has(plan_key):
		return issues

	visited_plans[plan_key] = true

	if plan_data.nodes.is_empty():
		issues.append("ImpactPlanData не содержит узлов.")
		return issues

	if plan_data.topology not in [
		ImpactPlanData.Topology.TREE,
		ImpactPlanData.Topology.QUEUE
	]:
		issues.append("ImpactPlanData содержит неизвестную топологию.")

	var nodes_by_id : Dictionary = {}

	for node_index in range(plan_data.nodes.size()):
		var node : ImpactNodeData = plan_data.nodes[node_index]
		var prefix := "nodes[%d]" % node_index

		if node == null:
			issues.append(prefix + ": узел отсутствует.")
			continue

		var node_id : String = node.node_id.strip_edges()

		if node_id.is_empty():
			issues.append(prefix + ": node_id пуст.")
		elif node_id != node.node_id:
			issues.append(prefix + ": node_id содержит пробелы по краям.")
		elif nodes_by_id.has(node_id):
			issues.append(prefix + ": node_id '%s' повторяется." % node_id)
		else:
			nodes_by_id[node_id] = node

		_validate_node(node, prefix, issues, visited_plans, visited_effects)

	if plan_data.topology == ImpactPlanData.Topology.QUEUE:
		for node in plan_data.nodes:
			if node != null and not node.parent_node_id.is_empty():
				issues.append(
					"Узел '%s': узел очереди не может иметь родителя."
					% node.node_id
				)
	else:
		_validate_tree(plan_data, nodes_by_id, issues)

	return issues


static func _validate_node(
	node : ImpactNodeData,
	prefix : String,
	issues : PackedStringArray,
	visited_plans : Dictionary,
	visited_effects : Dictionary
) -> void:
	if node.operation not in [
		Impact.Operation.DAMAGE,
		Impact.Operation.HEAL,
		Impact.Operation.SUMMON,
		Impact.Operation.APPLY_EFFECT,
		Impact.Operation.MOVE,
		Impact.Operation.CREATE_OBJECT,
		Impact.Operation.AFFECT_CELL
	]:
		issues.append(prefix + ": неизвестная операция.")

	if node.interaction_type not in [
		Impact.InteractionType.MELEE,
		Impact.InteractionType.RANGED,
		Impact.InteractionType.MAGIC,
		Impact.InteractionType.HEALING,
		Impact.InteractionType.SUMMON,
		Impact.InteractionType.EFFECT,
		Impact.InteractionType.MOVEMENT,
		Impact.InteractionType.OBJECT,
		Impact.InteractionType.CELL
	]:
		issues.append(prefix + ": неизвестный тип взаимодействия.")

	if node.operation in [Impact.Operation.DAMAGE, Impact.Operation.HEAL]:
		_validate_magnitude(node, prefix, issues)

	if node.operation == Impact.Operation.DAMAGE:
		if node.source_type.strip_edges().is_empty():
			issues.append(prefix + ": у урона отсутствует source_type.")

		if node.interaction_type in [
			Impact.InteractionType.HEALING,
			Impact.InteractionType.SUMMON,
			Impact.InteractionType.MOVEMENT,
			Impact.InteractionType.OBJECT,
			Impact.InteractionType.CELL
		]:
			issues.append(prefix + ": урон несовместим с типом взаимодействия.")

	if (
		node.operation == Impact.Operation.HEAL
		and node.interaction_type != Impact.InteractionType.HEALING
	):
		issues.append(prefix + ": лечение должно иметь тип HEALING.")

	if (
		node.operation == Impact.Operation.MOVE
		and node.interaction_type != Impact.InteractionType.MOVEMENT
	):
		issues.append(prefix + ": перемещение должно иметь тип MOVEMENT.")

	if node.operation == Impact.Operation.MOVE and node.magnitude != 1:
		issues.append(
			prefix + ": один MOVE-узел должен перемещать одного юнита."
		)

	if node.operation == Impact.Operation.APPLY_EFFECT:
		if node.interaction_type != Impact.InteractionType.EFFECT:
			issues.append(prefix + ": наложение эффекта должно иметь тип EFFECT.")

		if node.effect_data == null:
			issues.append(prefix + ": EffectData не назначен.")
		else:
			_validate_effect_data(
				node.effect_data,
				prefix + ".effect_data",
				issues,
				visited_plans,
				visited_effects
			)

	if (
		node.operation == Impact.Operation.SUMMON
		and node.interaction_type != Impact.InteractionType.SUMMON
	):
		issues.append(prefix + ": призыв должен иметь тип SUMMON.")

	if node.operation == Impact.Operation.SUMMON:
		if node.summon_unit_data == null:
			issues.append(prefix + ": UnitData призываемого юнита не назначен.")

		if node.magnitude != 1:
			issues.append(
				prefix
				+ ": один SUMMON-узел должен призывать ровно одного юнита."
			)
	elif node.summon_unit_data != null:
		issues.append(prefix + ": summon_unit_data допустим только для SUMMON.")

	if node.operation == Impact.Operation.CREATE_OBJECT:
		if node.interaction_type != Impact.InteractionType.OBJECT:
			issues.append(
				prefix + ": создание объекта должно иметь тип OBJECT."
			)

		if node.battlefield_object_data == null:
			issues.append(prefix + ": BattlefieldObjectData не назначен.")
		else:
			for object_issue in node.battlefield_object_data.get_validation_issues():
				issues.append(prefix + ".battlefield_object_data: " + object_issue)

		if node.magnitude != 1:
			issues.append(
				prefix
				+ ": один CREATE_OBJECT-узел должен создавать ровно один объект."
			)
	elif node.battlefield_object_data != null:
		issues.append(
			prefix
			+ ": battlefield_object_data допустим только для CREATE_OBJECT."
		)

	if node.operation == Impact.Operation.AFFECT_CELL:
		if node.interaction_type != Impact.InteractionType.CELL:
			issues.append(
				prefix + ": воздействие на клетку должно иметь тип CELL."
			)

		if node.source_type.strip_edges().is_empty():
			issues.append(
				prefix + ": у воздействия на клетку отсутствует source_type."
			)

		if node.magnitude != 1:
			issues.append(
				prefix + ": один AFFECT_CELL-узел должен отмечать одну клетку."
			)

	if (
		node.armor_penetration < InteractionResolver.MIN_ARMOR_PENETRATION
		or node.armor_penetration > InteractionResolver.MAX_ARMOR_PENETRATION
	):
		issues.append(prefix + ": бронебойность находится вне -5...5.")

	if (
		node.interaction_type == Impact.InteractionType.EFFECT
		and node.armor_penetration != 0
	):
		issues.append(prefix + ": EFFECT не использует бронебойность.")

	if (
		node.interaction_type in [
			Impact.InteractionType.MOVEMENT,
			Impact.InteractionType.OBJECT,
			Impact.InteractionType.CELL
		]
		and node.armor_penetration != 0
	):
		issues.append(
			prefix + ": MOVEMENT, OBJECT и CELL не используют бронебойность."
		)


static func _validate_magnitude(
	node : ImpactNodeData,
	prefix : String,
	issues : PackedStringArray
) -> void:
	match node.magnitude_source:
		ImpactNodeData.MagnitudeSource.FIXED:
			if (
				node.operation == Impact.Operation.HEAL
				and node.magnitude == 0
			):
				issues.append(
					prefix + ": величина лечения не может быть равна нулю."
				)
			elif (
				node.operation != Impact.Operation.HEAL
				and node.magnitude <= 0
			):
				issues.append(
					prefix + ": фиксированная величина должна быть больше нуля."
				)

		ImpactNodeData.MagnitudeSource.EVENT_APPLIED_AMOUNT:
			if (
				node.magnitude_numerator <= 0
				or node.magnitude_denominator <= 0
			):
				issues.append(
					prefix + ": коэффициент величины должен быть положительным."
				)

		_:
			issues.append(prefix + ": неизвестный источник величины.")

	if node.magnitude_rounding not in ImpactNodeData.MagnitudeRounding.values():
		issues.append(prefix + ": неизвестное правило округления величины.")


static func _validate_effect_data(
	effect_data : EffectData,
	prefix : String,
	issues : PackedStringArray,
	visited_plans : Dictionary,
	visited_effects : Dictionary
) -> void:
	var effect_key := effect_data.get_instance_id()

	if visited_effects.has(effect_key):
		return

	visited_effects[effect_key] = true

	if effect_data.effect_id.strip_edges().is_empty():
		issues.append(prefix + ": effect_id пуст.")

	if effect_data.duration != null:
		if (
			effect_data.duration.duration_unit
			!= EffectDurationData.DurationUnit.PERMANENT
			and effect_data.duration.amount <= 0
		):
			issues.append(prefix + ": длительность должна быть больше нуля.")

	_validate_passive_rules(effect_data, prefix, issues)

	var trigger_ids : Dictionary = {}

	for trigger_index in range(effect_data.triggers.size()):
		var trigger : EffectTriggerData = effect_data.triggers[trigger_index]
		var trigger_prefix := "%s.triggers[%d]" % [prefix, trigger_index]

		if trigger == null:
			issues.append(trigger_prefix + ": триггер отсутствует.")
			continue

		var trigger_id : String = trigger.trigger_id.strip_edges()

		if trigger_id.is_empty():
			issues.append(trigger_prefix + ": trigger_id пуст.")
		elif trigger_ids.has(trigger_id):
			issues.append(trigger_prefix + ": trigger_id повторяется.")
		else:
			trigger_ids[trigger_id] = true

		if trigger.response_plan_data == null:
			issues.append(trigger_prefix + ": план реакции отсутствует.")
		else:
			issues.append_array(
				_validate_plan(
					trigger.response_plan_data,
					visited_plans,
					visited_effects
				)
			)


static func _validate_passive_rules(
	effect_data : EffectData,
	prefix : String,
	issues : PackedStringArray
) -> void:
	for rule_index in range(effect_data.passive_rules.size()):
		var rule : PassiveRuleData = effect_data.passive_rules[rule_index]
		var rule_prefix := "%s.passive_rules[%d]" % [prefix, rule_index]

		if rule == null:
			issues.append(rule_prefix + ": правило отсутствует.")
			continue

		if rule.rule_type not in PassiveRuleData.RuleType.values():
			issues.append(rule_prefix + ": неизвестный тип правила.")
			continue

		if (
			rule.rule_type in [
				PassiveRuleData.RuleType.MODIFY_INITIATIVE,
				PassiveRuleData.RuleType.MODIFY_MOVEMENT
			]
			and rule.modifier_amount == 0
		):
			issues.append(rule_prefix + ": модификатор не должен быть нулевым.")

		if (
			rule.rule_type == PassiveRuleData.RuleType.PREVENT_DEATH
			and rule.restored_hp <= 0
		):
			issues.append(
				rule_prefix + ": восстановленное HP должно быть больше нуля."
			)


static func _validate_tree(
	plan_data : ImpactPlanData,
	nodes_by_id : Dictionary,
	issues : PackedStringArray
) -> void:
	var root_count := 0

	for node in plan_data.nodes:
		if node == null:
			continue

		if node.parent_node_id.is_empty():
			root_count += 1
			continue

		if not nodes_by_id.has(node.parent_node_id):
			issues.append(
				"Узел '%s': родитель '%s' не найден."
				% [node.node_id, node.parent_node_id]
			)
			continue

		var visited : Dictionary = {}
		var current : ImpactNodeData = node
		var depth := 0

		while current != null and not current.parent_node_id.is_empty():
			if visited.has(current.node_id):
				issues.append("Узел '%s': обнаружен цикл." % node.node_id)
				break

			visited[current.node_id] = true
			current = nodes_by_id.get(current.parent_node_id, null)
			depth += 1

			if depth > ImpactPlan.MAX_DEPTH:
				issues.append(
					"Узел '%s': глубина дерева превышает %d."
					% [node.node_id, ImpactPlan.MAX_DEPTH]
				)
				break

	if root_count == 0:
		issues.append("Дерево ImpactPlanData не содержит корневых узлов.")
