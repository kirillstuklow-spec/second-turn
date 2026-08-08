extends RefCounted

class_name AbilityAlgorithmRegistry


# ============================================================
# ВСТРОЕННЫЕ ИДЕНТИФИКАТОРЫ
# ============================================================

const ALGORITHM_DEAL_DAMAGE : StringName = &"deal_damage"
const ALGORITHM_HEAL_TARGET : StringName = &"heal_target"
const ALGORITHM_EXECUTE_IMPACT_PLAN : StringName = &"execute_impact_plan"

const PARAM_DAMAGE : StringName = &"damage"
const PARAM_HEAL : StringName = &"heal"
const PARAM_ARMOR_PENETRATION : StringName = &"armor_penetration"
const PARAM_KEYWORD : StringName = &"keyword"
const PARAM_RADIUS : StringName = &"radius"

const CONDITION_TARGET_MUST_BE_ALIVE : StringName = &"target_must_be_alive"
const CONDITION_TARGET_MUST_BE_ENEMY : StringName = &"target_must_be_enemy"
const CONDITION_TARGET_MUST_BE_ALLY : StringName = &"target_must_be_ally"

const TARGET_RULE_SINGLE_ANY_ENEMY : StringName = &"single_any_enemy"
const TARGET_RULE_SINGLE_ANY_ALLY : StringName = &"single_any_ally"
const TARGET_RULE_ALL_ENEMIES : StringName = &"all_enemies"
const TARGET_RULE_SINGLE_ADJACENT_ENEMY : StringName = (
	&"single_adjacent_enemy"
)
const TARGET_RULE_SINGLE_ADJACENT_ALLY : StringName = (
	&"single_adjacent_ally"
)
const TARGET_RULE_AREA_AROUND_UNIT : StringName = &"area_around_unit"
const TARGET_RULE_AREA_AROUND_CELL : StringName = &"area_around_cell"
const TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL : StringName = (
	&"single_empty_deployment_cell"
)


var _definitions : Dictionary = {}

var _known_conditions : Dictionary = {
	CONDITION_TARGET_MUST_BE_ALIVE: true,
	CONDITION_TARGET_MUST_BE_ENEMY: true,
	CONDITION_TARGET_MUST_BE_ALLY: true
}


func _init() -> void:
	_register_builtin_algorithms()


# ============================================================
# ПУБЛИЧНЫЙ КАТАЛОГ
# ============================================================

func has_algorithm(algorithm_id : StringName) -> bool:
	return _definitions.has(algorithm_id)


func get_definition(
	algorithm_id : StringName
) -> AbilityAlgorithmDefinition:
	return _definitions.get(
		algorithm_id,
		null
	) as AbilityAlgorithmDefinition


func get_definitions() -> Array[AbilityAlgorithmDefinition]:
	var definitions : Array[AbilityAlgorithmDefinition] = []

	for definition_value in _definitions.values():
		var definition := (
			definition_value as AbilityAlgorithmDefinition
		)

		if definition != null:
			definitions.append(definition)

	definitions.sort_custom(
		func(
			left : AbilityAlgorithmDefinition,
			right : AbilityAlgorithmDefinition
		) -> bool:
			return String(left.algorithm_id) < String(right.algorithm_id)
	)

	return definitions


func is_known_condition(condition_id : StringName) -> bool:
	return _known_conditions.has(condition_id)


# ============================================================
# СТРОГАЯ ВАЛИДАЦИЯ КОНКРЕТНОЙ СПОСОБНОСТИ
# ============================================================

func validate_unit_ability(
	unit_ability : UnitAbilityData
) -> AbilitySchemaValidationResult:
	var result := AbilitySchemaValidationResult.new()
	result.unit_ability = unit_ability

	if unit_ability == null:
		result.add_issue(
			AbilitySchemaIssue.Code.UNIT_ABILITY_MISSING,
			"unit_ability"
		)
		return result

	var ability_data := unit_ability.ability

	if ability_data == null:
		result.add_issue(
			AbilitySchemaIssue.Code.ABILITY_MECHANISM_MISSING,
			"ability"
		)
		return result

	var definition := _resolve_algorithm_definition(
		ability_data,
		result
	)

	if definition == null:
		return result

	result.algorithm_definition = definition

	_validate_action_type(
		ability_data,
		definition,
		result
	)

	var target_rule_id := _validate_target_rule(
		ability_data,
		definition,
		result
	)

	_validate_conditions(
		ability_data,
		unit_ability,
		result
	)

	_resolve_parameters(
		ability_data,
		unit_ability,
		definition,
		target_rule_id,
		result
	)

	_validate_declarative_impact_plan(
		unit_ability,
		definition,
		result
	)

	_validate_trigger_data(
		unit_ability,
		result
	)

	return result


# ============================================================
# РЕЕСТР ВСТРОЕННЫХ АЛГОРИТМОВ
# ============================================================

func _register_builtin_algorithms() -> void:
	_definitions.clear()

	_register_definition(_build_deal_damage_definition())
	_register_definition(_build_heal_target_definition())
	_register_definition(_build_execute_impact_plan_definition())


func _register_definition(
	definition : AbilityAlgorithmDefinition
) -> void:
	if definition == null or definition.algorithm_id == &"":
		push_error(
			"AbilityAlgorithmRegistry: invalid algorithm definition"
		)
		return

	if _definitions.has(definition.algorithm_id):
		push_error(
			"AbilityAlgorithmRegistry: duplicate algorithm_id: "
			+ String(definition.algorithm_id)
		)
		return

	_definitions[definition.algorithm_id] = definition


func _build_deal_damage_definition() -> AbilityAlgorithmDefinition:
	var definition := AbilityAlgorithmDefinition.new()
	definition.algorithm_id = ALGORITHM_DEAL_DAMAGE
	definition.display_name = "Нанесение урона"
	definition.description = (
		"Проверяет ключевое слово и броню, затем уменьшает HP цели."
	)
	definition.action_type = AbilityData.ActionType.ATTACK
	definition.allowed_target_rules = [
		TARGET_RULE_SINGLE_ANY_ENEMY,
		TARGET_RULE_ALL_ENEMIES,
		TARGET_RULE_SINGLE_ADJACENT_ENEMY,
		TARGET_RULE_AREA_AROUND_UNIT,
		TARGET_RULE_AREA_AROUND_CELL
	]

	var damage := _make_integer_spec(
		PARAM_DAMAGE,
		"Урон",
		"Базовая величина урона.",
		true,
		false,
		0,
		true,
		1,
		true,
		99
	)

	var armor_penetration := _make_integer_spec(
		PARAM_ARMOR_PENETRATION,
		"Бронебойность",
		"Изменяет эффективную броню. Допустимы значения от -5 до 5.",
		false,
		true,
		0,
		true,
		-5,
		true,
		5
	)

	var keyword := _make_string_spec(
		PARAM_KEYWORD,
		"Ключевое слово",
		"Технический ID для защит и иммунитетов.",
		true,
		false,
		"",
		false,
		true
	)

	var radius := _make_integer_spec(
		PARAM_RADIUS,
		"Радиус",
		"Манхэттенский радиус площадного воздействия.",
		false,
		false,
		0,
		true,
		0,
		true,
		99
	)
	radius.required_target_rules = [
		TARGET_RULE_AREA_AROUND_UNIT,
		TARGET_RULE_AREA_AROUND_CELL
	]

	definition.parameter_specs = [
		damage,
		armor_penetration,
		keyword,
		radius
	]

	return definition


func _build_heal_target_definition() -> AbilityAlgorithmDefinition:
	var definition := AbilityAlgorithmDefinition.new()
	definition.algorithm_id = ALGORITHM_HEAL_TARGET
	definition.display_name = "Лечение цели"
	definition.description = (
		"Проверяет тип и источник лечения, затем восстанавливает HP."
	)
	definition.action_type = AbilityData.ActionType.HEAL
	definition.allowed_target_rules = [
		TARGET_RULE_SINGLE_ANY_ALLY
	]

	var healing := _make_integer_spec(
		PARAM_HEAL,
		"Лечение",
		"Базовая величина восстановления HP.",
		true,
		false,
		0,
		true,
		1,
		true,
		99
	)

	var source_type := _make_string_spec(
		PARAM_KEYWORD,
		"Источник лечения",
		"Необязательный технический ID источника лечения.",
		false,
		true,
		"",
		true,
		true
	)

	definition.parameter_specs = [
		healing,
		source_type
	]

	return definition


func _build_execute_impact_plan_definition() -> AbilityAlgorithmDefinition:
	var definition := AbilityAlgorithmDefinition.new()
	definition.algorithm_id = ALGORITHM_EXECUTE_IMPACT_PLAN
	definition.display_name = "Декларативный план воздействий"
	definition.description = (
		"Строит дерево или очередь из редактируемого ImpactPlanData."
	)
	definition.allows_any_action_type = true
	definition.allowed_target_rules = [
		TARGET_RULE_SINGLE_ANY_ENEMY,
		TARGET_RULE_SINGLE_ANY_ALLY,
		TARGET_RULE_ALL_ENEMIES,
		TARGET_RULE_SINGLE_ADJACENT_ENEMY,
		TARGET_RULE_SINGLE_ADJACENT_ALLY,
		TARGET_RULE_AREA_AROUND_UNIT,
		TARGET_RULE_AREA_AROUND_CELL,
		TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL
	]
	definition.parameter_specs = []
	return definition


# ============================================================
# ВАЛИДАЦИЯ ИДЕНТИФИКАТОРОВ
# ============================================================

func _resolve_algorithm_definition(
	ability_data : AbilityData,
	result : AbilitySchemaValidationResult
) -> AbilityAlgorithmDefinition:
	var raw_algorithm_id := ability_data.algorithm_id
	var normalized_algorithm_id := raw_algorithm_id.strip_edges()

	if normalized_algorithm_id.is_empty():
		result.add_issue(
			AbilitySchemaIssue.Code.ALGORITHM_ID_MISSING,
			"ability.algorithm_id"
		)
		return null

	if raw_algorithm_id != normalized_algorithm_id:
		result.add_issue(
			AbilitySchemaIssue.Code.ALGORITHM_ID_HAS_SURROUNDING_WHITESPACE,
			"ability.algorithm_id",
			{
				"value": raw_algorithm_id
			}
		)
		return null

	var algorithm_id := StringName(normalized_algorithm_id)
	var definition := get_definition(algorithm_id)

	if definition == null:
		result.add_issue(
			AbilitySchemaIssue.Code.UNKNOWN_ALGORITHM,
			"ability.algorithm_id",
			{
				"algorithm_id": normalized_algorithm_id
			}
		)

	return definition


func _validate_action_type(
	ability_data : AbilityData,
	definition : AbilityAlgorithmDefinition,
	result : AbilitySchemaValidationResult
) -> void:
	if definition.allows_action_type(ability_data.action_type):
		return

	result.add_issue(
		AbilitySchemaIssue.Code.ACTION_TYPE_MISMATCH,
		"ability.action_type",
		{
			"algorithm_id": definition.algorithm_id,
			"expected": definition.action_type,
			"actual": ability_data.action_type
		}
	)


func _validate_declarative_impact_plan(
	unit_ability : UnitAbilityData,
	definition : AbilityAlgorithmDefinition,
	result : AbilitySchemaValidationResult
) -> void:
	if definition.algorithm_id != ALGORITHM_EXECUTE_IMPACT_PLAN:
		return

	if unit_ability.impact_plan_data == null:
		result.add_issue(
			AbilitySchemaIssue.Code.IMPACT_PLAN_MISSING,
			"unit_ability.impact_plan_data"
		)
		return

	var plan_issues := ImpactPlanDataValidator.validate(
		unit_ability.impact_plan_data
	)

	if plan_issues.is_empty():
		return

	result.add_issue(
		AbilitySchemaIssue.Code.IMPACT_PLAN_INVALID,
		"unit_ability.impact_plan_data",
		{
			"summary": " | ".join(plan_issues)
		}
	)


func _validate_trigger_data(
	unit_ability : UnitAbilityData,
	result : AbilitySchemaValidationResult
) -> void:
	var ability_data := unit_ability.ability

	if ability_data == null:
		return

	if ability_data.activation_mode != AbilityData.ActivationMode.TRIGGERED:
		if not unit_ability.triggers.is_empty():
			result.add_issue(
				AbilitySchemaIssue.Code.TRIGGERS_NOT_ALLOWED,
				"triggers"
			)

		return

	if unit_ability.triggers.is_empty():
		result.add_issue(
			AbilitySchemaIssue.Code.TRIGGERS_REQUIRED,
			"triggers"
		)
		return

	var seen_trigger_ids : Dictionary = {}

	for trigger_index in range(unit_ability.triggers.size()):
		var trigger := unit_ability.triggers[trigger_index]
		var field_path := "triggers[%d]" % trigger_index
		var trigger_issues := PackedStringArray()

		if trigger == null:
			trigger_issues.append("Триггер отсутствует.")
		else:
			var normalized_id := trigger.trigger_id.strip_edges()

			if normalized_id.is_empty():
				trigger_issues.append("trigger_id пуст.")
			elif normalized_id != trigger.trigger_id:
				trigger_issues.append("trigger_id содержит пробелы по краям.")
			elif seen_trigger_ids.has(normalized_id):
				trigger_issues.append("trigger_id повторяется.")
			else:
				seen_trigger_ids[normalized_id] = true

			if trigger.event_kind not in CombatEvent.Kind.values():
				trigger_issues.append("Неизвестный event_kind.")

			if trigger.owner_relation not in AbilityTriggerData.OwnerRelation.values():
				trigger_issues.append("Неизвестное отношение владельца к событию.")

			if (
				trigger.event_source_relation
				not in AbilityTriggerData.EventSourceRelation.values()
			):
				trigger_issues.append("Неизвестное отношение источника события.")

			if (
				trigger.interaction_filter
				not in AbilityTriggerData.InteractionFilter.values()
			):
				trigger_issues.append("Неизвестный фильтр interaction_type.")

			if (
				trigger.target_selection_policy
				not in AbilityTriggerData.TargetSelectionPolicy.values()
			):
				trigger_issues.append("Неизвестная политика выбора цели.")
			elif (
				trigger.target_selection_policy
				== AbilityTriggerData.TargetSelectionPolicy.PLAYER_CHOICE
				and StringName(ability_data.target_rule_id) not in [
					TARGET_RULE_SINGLE_ADJACENT_ENEMY,
					TARGET_RULE_SINGLE_ADJACENT_ALLY,
					TARGET_RULE_SINGLE_ANY_ENEMY,
					TARGET_RULE_SINGLE_ANY_ALLY
				]
			):
				trigger_issues.append(
					"Выбор игроком требует одиночного правила цели."
				)

			if (
				trigger.source_type_filter
				!= trigger.source_type_filter.strip_edges()
			):
				trigger_issues.append(
					"source_type_filter содержит пробелы по краям."
				)

		if not trigger_issues.is_empty():
			result.add_issue(
				AbilitySchemaIssue.Code.TRIGGER_INVALID,
				field_path,
				{
					"summary": " | ".join(trigger_issues)
				}
			)

	if unit_ability.action_point_cost != 0:
		result.add_issue(
			AbilitySchemaIssue.Code.TRIGGER_INVALID,
			"action_point_cost",
			{
				"summary": (
					"Автоматическая способность не должна расходовать AP."
				)
			}
		)


func _validate_target_rule(
	ability_data : AbilityData,
	definition : AbilityAlgorithmDefinition,
	result : AbilitySchemaValidationResult
) -> StringName:
	var raw_target_rule_id := ability_data.target_rule_id
	var normalized_target_rule_id := raw_target_rule_id.strip_edges()

	if normalized_target_rule_id.is_empty():
		result.add_issue(
			AbilitySchemaIssue.Code.TARGET_RULE_ID_MISSING,
			"ability.target_rule_id"
		)
		return &""

	if raw_target_rule_id != normalized_target_rule_id:
		result.add_issue(
			AbilitySchemaIssue.Code.TARGET_RULE_ID_HAS_SURROUNDING_WHITESPACE,
			"ability.target_rule_id",
			{
				"value": raw_target_rule_id
			}
		)
		return &""

	var target_rule_id := StringName(normalized_target_rule_id)

	if not definition.allows_target_rule(target_rule_id):
		result.add_issue(
			AbilitySchemaIssue.Code.TARGET_RULE_NOT_ALLOWED,
			"ability.target_rule_id",
			{
				"algorithm_id": definition.algorithm_id,
				"target_rule_id": target_rule_id
			}
		)

	return target_rule_id


func _validate_conditions(
	ability_data : AbilityData,
	unit_ability : UnitAbilityData,
	result : AbilitySchemaValidationResult
) -> void:
	var seen_conditions : Dictionary = {}

	_validate_condition_source(
		ability_data.default_conditions,
		"ability.default_conditions",
		seen_conditions,
		result
	)

	_validate_condition_source(
		unit_ability.conditions,
		"unit_ability.conditions",
		seen_conditions,
		result
	)


func _validate_condition_source(
	conditions : Array[String],
	field_path : String,
	seen_conditions : Dictionary,
	result : AbilitySchemaValidationResult
) -> void:
	for condition_index in range(conditions.size()):
		var raw_condition_id := conditions[condition_index]
		var normalized_condition_id := raw_condition_id.strip_edges()
		var item_path := "%s[%d]" % [field_path, condition_index]

		if normalized_condition_id.is_empty():
			result.add_issue(
				AbilitySchemaIssue.Code.CONDITION_ID_EMPTY,
				item_path
			)
			continue

		if raw_condition_id != normalized_condition_id:
			result.add_issue(
				AbilitySchemaIssue.Code.CONDITION_ID_HAS_SURROUNDING_WHITESPACE,
				item_path,
				{
					"condition_id": raw_condition_id
				}
			)
			continue

		var condition_id := StringName(normalized_condition_id)

		if not is_known_condition(condition_id):
			result.add_issue(
				AbilitySchemaIssue.Code.UNKNOWN_CONDITION,
				item_path,
				{
					"condition_id": condition_id
				}
			)
			continue

		if seen_conditions.has(condition_id):
			result.add_issue(
				AbilitySchemaIssue.Code.DUPLICATE_CONDITION,
				item_path,
				{
					"condition_id": condition_id
				}
			)
			continue

		seen_conditions[condition_id] = true


# ============================================================
# DEFAULTS + OVERRIDES
# ============================================================

func _resolve_parameters(
	ability_data : AbilityData,
	unit_ability : UnitAbilityData,
	definition : AbilityAlgorithmDefinition,
	target_rule_id : StringName,
	result : AbilitySchemaValidationResult
) -> void:
	var resolved_parameters : Dictionary = {}

	for parameter_spec in definition.parameter_specs:
		if parameter_spec == null:
			continue

		if parameter_spec.has_default_value:
			resolved_parameters[parameter_spec.parameter_id] = (
				parameter_spec.default_value
			)

	_validate_parameter_source(
		ability_data.default_parameters,
		"ability.default_parameters",
		definition,
		resolved_parameters,
		result
	)

	_validate_parameter_source(
		unit_ability.parameters,
		"unit_ability.parameters",
		definition,
		resolved_parameters,
		result
	)

	for parameter_spec in definition.parameter_specs:
		if parameter_spec == null:
			continue

		if not parameter_spec.is_required_for(target_rule_id):
			continue

		if resolved_parameters.has(parameter_spec.parameter_id):
			continue

		result.add_issue(
			AbilitySchemaIssue.Code.REQUIRED_PARAMETER_MISSING,
			"resolved_parameters.%s" % parameter_spec.parameter_id,
			{
				"parameter_id": parameter_spec.parameter_id
			}
		)

	result.resolved_parameters = resolved_parameters


func _validate_parameter_source(
	parameters : Dictionary,
	field_path : String,
	definition : AbilityAlgorithmDefinition,
	resolved_parameters : Dictionary,
	result : AbilitySchemaValidationResult
) -> void:
	var seen_parameter_ids : Dictionary = {}

	for raw_key in parameters:
		var raw_key_type := typeof(raw_key)

		if (
			raw_key_type != TYPE_STRING
			and raw_key_type != TYPE_STRING_NAME
		):
			result.add_issue(
				AbilitySchemaIssue.Code.PARAMETER_KEY_NOT_STRING,
				field_path,
				{
					"actual_type": type_string(raw_key_type)
				}
			)
			continue

		var raw_parameter_id := str(raw_key)
		var normalized_parameter_id := raw_parameter_id.strip_edges()
		var item_path := "%s.%s" % [field_path, raw_parameter_id]

		if raw_parameter_id != normalized_parameter_id:
			result.add_issue(
				AbilitySchemaIssue.Code.PARAMETER_KEY_HAS_SURROUNDING_WHITESPACE,
				item_path,
				{
					"parameter_id": raw_parameter_id
				}
			)
			continue

		var parameter_id := StringName(normalized_parameter_id)

		if seen_parameter_ids.has(parameter_id):
			result.add_issue(
				AbilitySchemaIssue.Code.DUPLICATE_PARAMETER,
				item_path,
				{
					"parameter_id": parameter_id
				}
			)
			continue

		seen_parameter_ids[parameter_id] = true

		var parameter_spec := definition.get_parameter_spec(
			parameter_id
		)

		if parameter_spec == null:
			result.add_issue(
				AbilitySchemaIssue.Code.UNKNOWN_PARAMETER,
				item_path,
				{
					"algorithm_id": definition.algorithm_id,
					"parameter_id": parameter_id
				}
			)
			continue

		var parameter_value : Variant = parameters[raw_key]

		_validate_parameter_value(
			parameter_spec,
			parameter_value,
			item_path,
			result
		)

		resolved_parameters[parameter_id] = parameter_value


func _validate_parameter_value(
	parameter_spec : AbilityParameterSpec,
	value : Variant,
	field_path : String,
	result : AbilitySchemaValidationResult
) -> void:
	if not parameter_spec.accepts_type(value):
		result.add_issue(
			AbilitySchemaIssue.Code.PARAMETER_TYPE_MISMATCH,
			field_path,
			{
				"parameter_id": parameter_spec.parameter_id,
				"expected_type": parameter_spec.get_expected_type_name(),
				"actual_type": type_string(typeof(value))
			}
		)
		return

	if parameter_spec.value_type == AbilityParameterSpec.ValueType.STRING:
		var text_value := str(value)

		if text_value.is_empty() and not parameter_spec.allow_empty_string:
			result.add_issue(
				AbilitySchemaIssue.Code.PARAMETER_EMPTY_STRING,
				field_path,
				{
					"parameter_id": parameter_spec.parameter_id
				}
			)

		if (
			parameter_spec.reject_surrounding_whitespace
			and text_value != text_value.strip_edges()
		):
			result.add_issue(
				AbilitySchemaIssue.Code.PARAMETER_VALUE_HAS_SURROUNDING_WHITESPACE,
				field_path,
				{
					"parameter_id": parameter_spec.parameter_id
				}
			)

		return

	if (
		parameter_spec.value_type
		!= AbilityParameterSpec.ValueType.INTEGER
		and parameter_spec.value_type
		!= AbilityParameterSpec.ValueType.FLOAT
	):
		return

	var numeric_value := float(value)

	if (
		parameter_spec.has_minimum
		and numeric_value < parameter_spec.minimum_value
	):
		result.add_issue(
			AbilitySchemaIssue.Code.PARAMETER_BELOW_MINIMUM,
			field_path,
			{
				"parameter_id": parameter_spec.parameter_id,
				"minimum": parameter_spec.minimum_value,
				"actual": numeric_value
			}
		)

	if (
		parameter_spec.has_maximum
		and numeric_value > parameter_spec.maximum_value
	):
		result.add_issue(
			AbilitySchemaIssue.Code.PARAMETER_ABOVE_MAXIMUM,
			field_path,
			{
				"parameter_id": parameter_spec.parameter_id,
				"maximum": parameter_spec.maximum_value,
				"actual": numeric_value
			}
		)


# ============================================================
# ФАБРИКИ СПЕЦИФИКАЦИЙ
# ============================================================

func _make_integer_spec(
	parameter_id : StringName,
	display_name : String,
	description : String,
	is_required : bool,
	has_default_value : bool,
	default_value : int,
	has_minimum : bool,
	minimum_value : int,
	has_maximum : bool,
	maximum_value : int
) -> AbilityParameterSpec:
	var spec := AbilityParameterSpec.new()
	spec.parameter_id = parameter_id
	spec.display_name = display_name
	spec.description = description
	spec.value_type = AbilityParameterSpec.ValueType.INTEGER
	spec.is_required = is_required
	spec.has_default_value = has_default_value
	spec.default_value = default_value
	spec.has_minimum = has_minimum
	spec.minimum_value = minimum_value
	spec.has_maximum = has_maximum
	spec.maximum_value = maximum_value
	return spec


func _make_string_spec(
	parameter_id : StringName,
	display_name : String,
	description : String,
	is_required : bool,
	has_default_value : bool,
	default_value : String,
	allow_empty_string : bool,
	reject_surrounding_whitespace : bool
) -> AbilityParameterSpec:
	var spec := AbilityParameterSpec.new()
	spec.parameter_id = parameter_id
	spec.display_name = display_name
	spec.description = description
	spec.value_type = AbilityParameterSpec.ValueType.STRING
	spec.is_required = is_required
	spec.has_default_value = has_default_value
	spec.default_value = default_value
	spec.allow_empty_string = allow_empty_string
	spec.reject_surrounding_whitespace = reject_surrounding_whitespace
	return spec
