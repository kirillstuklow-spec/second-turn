extends RefCounted

class_name StatusEffectSystem


var _next_effect_runtime_sequence : int = 1


func apply_effect(
	impact : Impact,
	battle_state : BattleState
) -> EffectApplicationResult:
	var error_message := _get_application_error(impact, battle_state)

	if not error_message.is_empty():
		return EffectApplicationResult.create(
			EffectApplicationResult.Status.REJECTED,
			null,
			error_message
		)

	var carrier := impact.target_unit
	var effect_data := impact.effect_data
	var existing := get_effect(carrier, StringName(effect_data.effect_id))
	var activation_serial := battle_state.turn_state.activation_serial
	var round_number := battle_state.round_number

	if existing != null:
		match effect_data.reapply_policy:
			EffectData.ReapplyPolicy.REFRESH:
				existing.refresh_source_and_duration(
					impact.source_unit,
					impact.source_ability_data,
					activation_serial,
					round_number
				)
				return EffectApplicationResult.create(
					EffectApplicationResult.Status.REFRESHED,
					existing
				)

			EffectData.ReapplyPolicy.IGNORE:
				return EffectApplicationResult.create(
					EffectApplicationResult.Status.UNCHANGED,
					existing,
					"Effect reapplication was ignored by policy."
				)

			EffectData.ReapplyPolicy.REPLACE:
				carrier.active_effects.erase(existing)

	var effect_runtime := EffectRuntime.new()
	effect_runtime.setup(
		StringName(
			"effect_runtime_%06d"
			% _next_effect_runtime_sequence
		),
		effect_data,
		impact.source_unit,
		impact.source_ability_data,
		carrier,
		activation_serial,
		round_number
	)
	_next_effect_runtime_sequence += 1
	carrier.active_effects.append(effect_runtime)

	return EffectApplicationResult.create(
		EffectApplicationResult.Status.APPLIED,
		effect_runtime
	)


func get_effect(
	carrier : UnitRuntime,
	effect_id : StringName
) -> EffectRuntime:
	if carrier == null or effect_id == &"":
		return null

	for effect_runtime in carrier.active_effects:
		if (
			effect_runtime != null
			and effect_runtime.get_effect_id() == effect_id
		):
			return effect_runtime

	return null


func remove_effect(
	carrier : UnitRuntime,
	effect_runtime : EffectRuntime
) -> bool:
	if carrier == null or effect_runtime == null:
		return false

	if not carrier.active_effects.has(effect_runtime):
		return false

	carrier.active_effects.erase(effect_runtime)
	return true


func finish_activation(
	carrier : UnitRuntime,
	activation_serial : int
) -> void:
	if carrier == null:
		return

	var active_copy : Array[EffectRuntime] = []
	active_copy.append_array(carrier.active_effects)

	for effect_runtime in active_copy:
		if (
			effect_runtime == null
			or effect_runtime.data == null
			or effect_runtime.data.duration == null
		):
			continue

		var duration := effect_runtime.data.duration

		if (
			duration.duration_unit
			!= EffectDurationData.DurationUnit.CARRIER_ACTIVATIONS
		):
			continue

		if (
			duration.skip_application_activation
			and effect_runtime.last_application_activation_serial
			== activation_serial
		):
			continue

		effect_runtime.remaining_duration -= 1

		if effect_runtime.remaining_duration <= 0:
			remove_effect(carrier, effect_runtime)


func finish_round(
	units : Array[UnitRuntime],
	completed_round_number : int = -1
) -> void:
	for carrier in units:
		if carrier == null:
			continue

		var active_copy : Array[EffectRuntime] = []
		active_copy.append_array(carrier.active_effects)

		for effect_runtime in active_copy:
			if (
				effect_runtime == null
				or effect_runtime.data == null
				or effect_runtime.data.duration == null
			):
				continue

			if (
				effect_runtime.data.duration.duration_unit
				!= EffectDurationData.DurationUnit.ROUNDS
			):
				continue

			if (
				effect_runtime.data.duration.skip_application_round
				and completed_round_number >= 0
				and effect_runtime.last_application_round
				== completed_round_number
			):
				continue

			effect_runtime.remaining_duration -= 1

			if effect_runtime.remaining_duration <= 0:
				remove_effect(carrier, effect_runtime)


func blocks_healing_kind(
	carrier : UnitRuntime,
	healing_kind : Impact.HealingKind
) -> EffectRuntime:
	if carrier == null:
		return null

	for effect_runtime in carrier.active_effects:
		if effect_runtime == null or effect_runtime.data == null:
			continue

		for passive_rule in effect_runtime.data.passive_rules:
			if passive_rule == null:
				continue

			if (
				passive_rule.rule_type
				== PassiveRuleData.RuleType.BLOCK_HEALING_KIND
				and passive_rule.healing_kind == healing_kind
			):
				return effect_runtime

	return null


func get_additive_modifier(
	carrier : UnitRuntime,
	rule_type : PassiveRuleData.RuleType
) -> int:
	if carrier == null:
		return 0

	if rule_type not in [
		PassiveRuleData.RuleType.MODIFY_INITIATIVE,
		PassiveRuleData.RuleType.MODIFY_MOVEMENT
	]:
		return 0

	var total := 0

	for effect_runtime in carrier.active_effects:
		if effect_runtime == null or effect_runtime.data == null:
			continue

		for passive_rule in effect_runtime.data.passive_rules:
			if passive_rule == null or passive_rule.rule_type != rule_type:
				continue

			total += passive_rule.modifier_amount

	return total


# Возвращает из DEATH_PENDING первый подходящий эффект и расходует весь
# EffectRuntime. Если предотвращение невозможно, состояние не меняется.
func try_prevent_death(carrier : UnitRuntime) -> EffectRuntime:
	if carrier == null or not carrier.is_death_pending():
		return null

	var effects_at_attempt : Array[EffectRuntime] = []
	effects_at_attempt.append_array(carrier.active_effects)

	for effect_runtime in effects_at_attempt:
		if effect_runtime == null or effect_runtime.data == null:
			continue

		for passive_rule in effect_runtime.data.passive_rules:
			if (
				passive_rule == null
				or passive_rule.rule_type
				!= PassiveRuleData.RuleType.PREVENT_DEATH
			):
				continue

			if not carrier.cancel_pending_death(passive_rule.restored_hp):
				continue

			remove_effect(carrier, effect_runtime)
			return effect_runtime

	return null


func clear_runtime_sequence() -> void:
	_next_effect_runtime_sequence = 1


func _get_application_error(
	impact : Impact,
	battle_state : BattleState
) -> String:
	if impact == null:
		return "StatusEffectSystem: impact is null"

	if impact.operation != Impact.Operation.APPLY_EFFECT:
		return "StatusEffectSystem: impact is not APPLY_EFFECT"

	if impact.effect_data == null:
		return "StatusEffectSystem: effect data is missing"

	if impact.effect_data.effect_id.strip_edges().is_empty():
		return "StatusEffectSystem: effect_id is empty"

	if impact.target_unit == null or not impact.target_unit.is_alive:
		return "StatusEffectSystem: carrier is unavailable"

	if impact.source_unit == null:
		return "StatusEffectSystem: source unit is missing"

	if battle_state == null:
		return "StatusEffectSystem: battle state is missing"

	if not battle_state.units.has(impact.target_unit):
		return "StatusEffectSystem: carrier is absent from battle"

	if not battle_state.units.has(impact.source_unit):
		return "StatusEffectSystem: source is absent from battle"

	return ""
