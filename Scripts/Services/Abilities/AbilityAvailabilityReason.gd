extends RefCounted

class_name AbilityAvailabilityReason


enum Code {
	BATTLE_STATE_MISSING,
	ABILITY_RUNTIME_MISSING,
	ABILITY_DATA_MISSING,
	ABILITY_MECHANISM_MISSING,
	ABILITY_SCHEMA_INVALID,
	OWNER_MISSING,
	BATTLE_OVER,
	OWNER_DEAD,
	OWNER_NOT_ACTIVE,
	ABILITY_NOT_OWNED,
	INSUFFICIENT_ACTION_POINTS,
	COOLDOWN_ACTIVE,
	CHARGES_DEPLETED,
	BATTLE_USE_LIMIT_REACHED,
	ROUND_USE_LIMIT_REACHED,
	ACTIVATION_USE_LIMIT_REACHED,
	EXTERNAL_BLOCKER,
	INSUFFICIENT_HEALTH_POINTS
}


var code : int = Code.ABILITY_RUNTIME_MISSING

var context : Dictionary = {}


static func create(
	reason_code : int,
	reason_context : Dictionary = {}
) -> AbilityAvailabilityReason:
	var reason := AbilityAvailabilityReason.new()
	reason.code = reason_code
	reason.context = reason_context.duplicate(true)
	return reason


func get_message() -> String:
	match code:
		Code.BATTLE_STATE_MISSING:
			return "Состояние боя недоступно."

		Code.ABILITY_RUNTIME_MISSING:
			return "Runtime способности не создан."

		Code.ABILITY_DATA_MISSING:
			return "У Runtime способности отсутствуют данные."

		Code.ABILITY_MECHANISM_MISSING:
			return "Для способности не назначен игровой механизм."

		Code.ABILITY_SCHEMA_INVALID:
			return "Некорректная схема способности:\n%s" % (
				str(context.get("summary", "Неизвестная ошибка схемы."))
			)

		Code.OWNER_MISSING:
			return "У способности отсутствует владелец."

		Code.BATTLE_OVER:
			return "Бой уже завершён."

		Code.OWNER_DEAD:
			return "Владелец способности не является живым."

		Code.OWNER_NOT_ACTIVE:
			return "Сейчас активен другой юнит."

		Code.ABILITY_NOT_OWNED:
			return "Способность не принадлежит этому юниту."

		Code.INSUFFICIENT_ACTION_POINTS:
			return "Недостаточно AP: нужно %d, доступно %d." % [
				int(context.get("required", 0)),
				int(context.get("available", 0))
			]

		Code.INSUFFICIENT_HEALTH_POINTS:
			return (
				"Недостаточно HP для безопасной оплаты: нужно %d, "
				+ "доступно к трате %d."
			) % [
				int(context.get("required", 0)),
				int(context.get("available", 0))
			]

		Code.COOLDOWN_ACTIVE:
			return "Кулдаун: осталось полных раундов — %d." % (
				int(context.get("remaining", 0))
			)

		Code.CHARGES_DEPLETED:
			return "Заряды способности закончились."

		Code.BATTLE_USE_LIMIT_REACHED:
			return "Достигнут лимит применений за бой."

		Code.ROUND_USE_LIMIT_REACHED:
			return "Достигнут лимит применений за раунд."

		Code.ACTIVATION_USE_LIMIT_REACHED:
			return "Достигнут лимит применений за активацию."

		Code.EXTERNAL_BLOCKER:
			return "Способность заблокирована: %s." % (
				str(context.get("blocker_id", "unknown"))
			)

	return "Способность недоступна по неизвестной причине."
