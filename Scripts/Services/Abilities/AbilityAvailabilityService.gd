extends RefCounted

class_name AbilityAvailabilityService


var algorithm_registry : AbilityAlgorithmRegistry = null


func _init(
	new_algorithm_registry : AbilityAlgorithmRegistry = null
) -> void:
	set_algorithm_registry(new_algorithm_registry)


func set_algorithm_registry(
	new_algorithm_registry : AbilityAlgorithmRegistry
) -> void:
	algorithm_registry = new_algorithm_registry

	if algorithm_registry == null:
		algorithm_registry = AbilityAlgorithmRegistry.new()


# ============================================================
# ПУБЛИЧНАЯ ПРОВЕРКА ДОСТУПНОСТИ
# ============================================================

func evaluate(
	battle_state : BattleState,
	ability_runtime : UnitAbilityRuntime,
	external_blockers : Array[StringName] = []
) -> AbilityAvailabilityResult:
	var result := AbilityAvailabilityResult.new()
	result.ability_runtime = ability_runtime

	if ability_runtime == null:
		result.add_reason(
			AbilityAvailabilityReason.Code.ABILITY_RUNTIME_MISSING
		)
		return result

	if ability_runtime.data == null:
		result.add_reason(
			AbilityAvailabilityReason.Code.ABILITY_DATA_MISSING
		)
		return result

	if ability_runtime.data.ability == null:
		result.add_reason(
			AbilityAvailabilityReason.Code.ABILITY_MECHANISM_MISSING
		)
	else:
		_evaluate_ability_schema(result, ability_runtime)

	var owner := ability_runtime.owner

	if owner == null:
		result.add_reason(
			AbilityAvailabilityReason.Code.OWNER_MISSING
		)
		return result

	if battle_state == null:
		result.add_reason(
			AbilityAvailabilityReason.Code.BATTLE_STATE_MISSING
		)
	else:
		if battle_state.is_battle_over:
			result.add_reason(
				AbilityAvailabilityReason.Code.BATTLE_OVER
			)

		if battle_state.active_unit != owner:
			result.add_reason(
				AbilityAvailabilityReason.Code.OWNER_NOT_ACTIVE
			)

	if not owner.is_alive:
		result.add_reason(
			AbilityAvailabilityReason.Code.OWNER_DEAD
		)

	if not owner.active_abilities.has(ability_runtime):
		result.add_reason(
			AbilityAvailabilityReason.Code.ABILITY_NOT_OWNED
		)

	_evaluate_action_points(result, ability_runtime)
	_evaluate_health_points(result, ability_runtime)
	_evaluate_cooldown_and_charges(result, ability_runtime)
	_evaluate_usage_limits(result, ability_runtime)
	_evaluate_external_blockers(result, external_blockers)

	return result


func _evaluate_ability_schema(
	result : AbilityAvailabilityResult,
	ability_runtime : UnitAbilityRuntime
) -> void:
	if algorithm_registry == null:
		algorithm_registry = AbilityAlgorithmRegistry.new()

	var schema_result := algorithm_registry.validate_unit_ability(
		ability_runtime.data
	)

	if schema_result.is_valid:
		return

	result.add_reason(
		AbilityAvailabilityReason.Code.ABILITY_SCHEMA_INVALID,
		{
			"summary": schema_result.get_summary()
		}
	)


# ============================================================
# ЧАСТНЫЕ ПРОВЕРКИ
# ============================================================

func _evaluate_action_points(
	result : AbilityAvailabilityResult,
	ability_runtime : UnitAbilityRuntime
) -> void:
	var required := ability_runtime.data.action_point_cost
	var available := ability_runtime.owner.action_points_remaining

	if available >= required:
		return

	result.add_reason(
		AbilityAvailabilityReason.Code.INSUFFICIENT_ACTION_POINTS,
		{
			"required": required,
			"available": available
		}
	)


func _evaluate_health_points(
	result : AbilityAvailabilityResult,
	ability_runtime : UnitAbilityRuntime
) -> void:
	var required := ability_runtime.data.health_point_cost
	var available : int = maxi(
		0,
		ability_runtime.owner.current_hp - 1
	)

	if available >= required:
		return

	result.add_reason(
		AbilityAvailabilityReason.Code.INSUFFICIENT_HEALTH_POINTS,
		{
			"required": required,
			"available": available
		}
	)


func _evaluate_cooldown_and_charges(
	result : AbilityAvailabilityResult,
	ability_runtime : UnitAbilityRuntime
) -> void:
	if ability_runtime.remaining_cooldown > 0:
		result.add_reason(
			AbilityAvailabilityReason.Code.COOLDOWN_ACTIVE,
			{
				"remaining": ability_runtime.remaining_cooldown
			}
		)

	if (
		ability_runtime.has_limited_charges()
		and ability_runtime.remaining_charges <= 0
	):
		result.add_reason(
			AbilityAvailabilityReason.Code.CHARGES_DEPLETED
		)


func _evaluate_usage_limits(
	result : AbilityAvailabilityResult,
	ability_runtime : UnitAbilityRuntime
) -> void:
	var data := ability_runtime.data

	if (
		data.max_uses_per_battle > 0
		and ability_runtime.uses_this_battle
		>= data.max_uses_per_battle
	):
		result.add_reason(
			AbilityAvailabilityReason.Code.BATTLE_USE_LIMIT_REACHED
		)

	if (
		data.max_uses_per_round > 0
		and ability_runtime.uses_this_round
		>= data.max_uses_per_round
	):
		result.add_reason(
			AbilityAvailabilityReason.Code.ROUND_USE_LIMIT_REACHED
		)

	if (
		data.max_uses_per_activation > 0
		and ability_runtime.uses_this_activation
		>= data.max_uses_per_activation
	):
		result.add_reason(
			AbilityAvailabilityReason.Code.ACTIVATION_USE_LIMIT_REACHED
		)


func _evaluate_external_blockers(
	result : AbilityAvailabilityResult,
	external_blockers : Array[StringName]
) -> void:
	var unique_blockers : Dictionary = {}

	for blocker_id in external_blockers:
		if blocker_id == &"":
			continue

		if unique_blockers.has(blocker_id):
			continue

		unique_blockers[blocker_id] = true

		result.add_reason(
			AbilityAvailabilityReason.Code.EXTERNAL_BLOCKER,
			{
				"blocker_id": blocker_id
			}
		)
