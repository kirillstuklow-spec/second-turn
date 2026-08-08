extends RefCounted

class_name MagnitudeResolver


# Чистый расчёт величины одного Impact. Resolver не читает BattleState, не
# ищет эффекты и ничего не изменяет: ему передаются только данные узла и
# уже зафиксированное событие, если оно является источником величины.
static func resolve_node_magnitude(
	node : ImpactNodeData,
	event : CombatEvent = null
) -> Dictionary:
	if node == null:
		return _reject("MagnitudeResolver: ImpactNodeData is missing")

	match node.magnitude_source:
		ImpactNodeData.MagnitudeSource.FIXED:
			if node.magnitude <= 0:
				return _reject(
					"MagnitudeResolver: fixed magnitude must be positive"
				)

			return _accept(node.magnitude)

		ImpactNodeData.MagnitudeSource.EVENT_APPLIED_AMOUNT:
			if event == null:
				return _reject(
					"MagnitudeResolver: event magnitude source is unavailable"
				)

			if event.applied_amount <= 0:
				return _reject(
					"MagnitudeResolver: event applied amount must be positive"
				)

			if (
				node.magnitude_numerator <= 0
				or node.magnitude_denominator <= 0
			):
				return _reject(
					"MagnitudeResolver: magnitude ratio must be positive"
				)

			var scaled_amount := (
				event.applied_amount * node.magnitude_numerator
			)
			var resolved_amount : int = int(
				scaled_amount / node.magnitude_denominator
			)

			if (
				node.magnitude_rounding
				== ImpactNodeData.MagnitudeRounding.CEIL
				and scaled_amount % node.magnitude_denominator != 0
			):
				resolved_amount += 1

			if resolved_amount <= 0:
				return _reject(
					"MagnitudeResolver: resolved magnitude must be positive"
				)

			return _accept(resolved_amount)

	return _reject("MagnitudeResolver: unknown magnitude source")


static func _accept(value : int) -> Dictionary:
	return {
		"is_valid": true,
		"value": value,
		"message": ""
	}


static func _reject(message : String) -> Dictionary:
	return {
		"is_valid": false,
		"value": 0,
		"message": message
	}
