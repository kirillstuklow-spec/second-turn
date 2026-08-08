extends RefCounted

class_name AbilitySchemaIssue


enum Code {
	UNIT_ABILITY_MISSING,
	ABILITY_MECHANISM_MISSING,
	ALGORITHM_ID_MISSING,
	ALGORITHM_ID_HAS_SURROUNDING_WHITESPACE,
	UNKNOWN_ALGORITHM,
	ACTION_TYPE_MISMATCH,
	TARGET_RULE_ID_MISSING,
	TARGET_RULE_ID_HAS_SURROUNDING_WHITESPACE,
	TARGET_RULE_NOT_ALLOWED,
	CONDITION_ID_EMPTY,
	CONDITION_ID_HAS_SURROUNDING_WHITESPACE,
	UNKNOWN_CONDITION,
	DUPLICATE_CONDITION,
	PARAMETER_KEY_NOT_STRING,
	PARAMETER_KEY_HAS_SURROUNDING_WHITESPACE,
	DUPLICATE_PARAMETER,
	UNKNOWN_PARAMETER,
	REQUIRED_PARAMETER_MISSING,
	PARAMETER_TYPE_MISMATCH,
	PARAMETER_EMPTY_STRING,
	PARAMETER_VALUE_HAS_SURROUNDING_WHITESPACE,
	PARAMETER_BELOW_MINIMUM,
	PARAMETER_ABOVE_MAXIMUM,
	IMPACT_PLAN_MISSING,
	IMPACT_PLAN_INVALID,
	TRIGGERS_REQUIRED,
	TRIGGERS_NOT_ALLOWED,
	TRIGGER_INVALID
}


var code : Code = Code.UNIT_ABILITY_MISSING

var field_path : String = ""

var context : Dictionary = {}


static func create(
	issue_code : Code,
	issue_field_path : String,
	issue_context : Dictionary = {}
) -> AbilitySchemaIssue:
	var issue := AbilitySchemaIssue.new()
	issue.code = issue_code
	issue.field_path = issue_field_path
	issue.context = issue_context.duplicate(true)
	return issue


func get_message() -> String:
	match code:
		Code.UNIT_ABILITY_MISSING:
			return "Данные конкретной способности отсутствуют."

		Code.ABILITY_MECHANISM_MISSING:
			return "Для способности не назначен AbilityData."

		Code.ALGORITHM_ID_MISSING:
			return "Не указан algorithm_id."

		Code.ALGORITHM_ID_HAS_SURROUNDING_WHITESPACE:
			return "algorithm_id содержит пробелы по краям: '%s'." % (
				str(context.get("value", ""))
			)

		Code.UNKNOWN_ALGORITHM:
			return "Неизвестный algorithm_id: '%s'." % (
				str(context.get("algorithm_id", ""))
			)

		Code.ACTION_TYPE_MISMATCH:
			return (
				"Алгоритм '%s' ожидает action_type=%d, получено %d."
				% [
					str(context.get("algorithm_id", "")),
					int(context.get("expected", -1)),
					int(context.get("actual", -1))
				]
			)

		Code.TARGET_RULE_ID_MISSING:
			return "Не указан target_rule_id."

		Code.TARGET_RULE_ID_HAS_SURROUNDING_WHITESPACE:
			return "target_rule_id содержит пробелы по краям: '%s'." % (
				str(context.get("value", ""))
			)

		Code.TARGET_RULE_NOT_ALLOWED:
			return "Алгоритм '%s' не поддерживает target_rule_id '%s'." % [
				str(context.get("algorithm_id", "")),
				str(context.get("target_rule_id", ""))
			]

		Code.CONDITION_ID_EMPTY:
			return "Условие способности содержит пустой ID."

		Code.CONDITION_ID_HAS_SURROUNDING_WHITESPACE:
			return "ID условия содержит пробелы по краям: '%s'." % (
				str(context.get("condition_id", ""))
			)

		Code.UNKNOWN_CONDITION:
			return "Неизвестное условие способности: '%s'." % (
				str(context.get("condition_id", ""))
			)

		Code.DUPLICATE_CONDITION:
			return "Условие '%s' указано больше одного раза." % (
				str(context.get("condition_id", ""))
			)

		Code.PARAMETER_KEY_NOT_STRING:
			return "Ключ параметра должен быть String или StringName."

		Code.PARAMETER_KEY_HAS_SURROUNDING_WHITESPACE:
			return "Ключ параметра содержит пробелы по краям: '%s'." % (
				str(context.get("parameter_id", ""))
			)

		Code.DUPLICATE_PARAMETER:
			return "Параметр '%s' указан повторно в одном наборе." % (
				str(context.get("parameter_id", ""))
			)

		Code.UNKNOWN_PARAMETER:
			return "Алгоритм '%s' не знает параметр '%s'." % [
				str(context.get("algorithm_id", "")),
				str(context.get("parameter_id", ""))
			]

		Code.REQUIRED_PARAMETER_MISSING:
			return "Не указан обязательный параметр '%s'." % (
				str(context.get("parameter_id", ""))
			)

		Code.PARAMETER_TYPE_MISMATCH:
			return "Параметр '%s' должен иметь тип %s, получен %s." % [
				str(context.get("parameter_id", "")),
				str(context.get("expected_type", "unknown")),
				str(context.get("actual_type", "unknown"))
			]

		Code.PARAMETER_EMPTY_STRING:
			return "Параметр '%s' не может быть пустой строкой." % (
				str(context.get("parameter_id", ""))
			)

		Code.PARAMETER_VALUE_HAS_SURROUNDING_WHITESPACE:
			return "Значение параметра '%s' содержит пробелы по краям." % (
				str(context.get("parameter_id", ""))
			)

		Code.PARAMETER_BELOW_MINIMUM:
			return "Параметр '%s' меньше допустимого минимума %s." % [
				str(context.get("parameter_id", "")),
				str(context.get("minimum", ""))
			]

		Code.PARAMETER_ABOVE_MAXIMUM:
			return "Параметр '%s' больше допустимого максимума %s." % [
				str(context.get("parameter_id", "")),
				str(context.get("maximum", ""))
			]

		Code.IMPACT_PLAN_MISSING:
			return "Для декларативной способности не назначен ImpactPlanData."

		Code.IMPACT_PLAN_INVALID:
			return "Некорректный ImpactPlanData: %s" % (
				str(context.get("summary", ""))
			)

		Code.TRIGGERS_REQUIRED:
			return "Для автоматической способности не назначен триггер."

		Code.TRIGGERS_NOT_ALLOWED:
			return (
				"Триггеры допустимы только для activation_mode=TRIGGERED."
			)

		Code.TRIGGER_INVALID:
			return "Некорректный триггер способности: %s" % (
				str(context.get("summary", ""))
			)

	return "Неизвестная ошибка схемы способности."
