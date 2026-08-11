extends Node

class_name TurnPipeline


const RNG_PURPOSE_INITIATIVE_MODIFIER : StringName = (
	&"initiative_modifier"
)


# ============================================================
# ССЫЛКИ НА СОСТОЯНИЕ БОЯ
# ============================================================

var battle_state : BattleState = null
var event_queue : EventQueue = null
var status_effect_system : StatusEffectSystem = null
var impact_executor : ImpactExecutor = null

var _pending_activation_end_unit : UnitRuntime = null

# ============================================================
# НАСТРОЙКА PIPELINE
# ============================================================

func configure(
	new_battle_state : BattleState,
	new_event_queue : EventQueue,
	new_status_effect_system : StatusEffectSystem = null,
	new_impact_executor : ImpactExecutor = null
) -> void:
	battle_state = new_battle_state
	event_queue = new_event_queue
	status_effect_system = new_status_effect_system
	impact_executor = new_impact_executor
	_pending_activation_end_unit = null

	print("TurnPipeline configured")


# ============================================================
# СТАРТ БОЕВОГО FLOW
# ============================================================

func start_battle_flow() -> void:
	if battle_state == null:
		push_error(
			"TurnPipeline: battle_state is null"
		)
		return

	if battle_state.is_battle_over:
		print(
			"TurnPipeline: battle is already over"
		)
		return

	battle_state.turn_state.clear()
	_pending_activation_end_unit = null

	_start_new_round()
# ============================================================
# ЗАВЕРШЕНИЕ АКТИВАЦИИ
# ============================================================

func end_current_activation() -> void:
	if battle_state == null:
		push_error("TurnPipeline: battle_state is null")
		return

	if battle_state.is_battle_over:
		print("TurnPipeline: battle is over, cannot end activation")
		return

	if battle_state.pending_decision != null:
		print("TurnPipeline: cannot end activation during a pending decision")
		return

	var ending_unit := battle_state.active_unit

	if ending_unit != null:
		print("TurnPipeline: activation ended for ", ending_unit.data.unit_name)

		if impact_executor != null:
			var event_result := impact_executor.process_unit_event(
				CombatEvent.Kind.ACTIVATION_ENDED,
				ending_unit,
				battle_state
			)

			if not event_result.is_successful():
				push_error(
					"TurnPipeline: activation-end reactions failed: "
					+ event_result.get_summary()
				)

			if battle_state.pending_decision != null:
				_pending_activation_end_unit = ending_unit
				return

	_complete_activation_end(ending_unit)


func resume_after_pending_decision() -> void:
	if (
		battle_state == null
		or battle_state.pending_decision != null
		or _pending_activation_end_unit == null
	):
		return

	var ending_unit := _pending_activation_end_unit
	_pending_activation_end_unit = null
	_complete_activation_end(ending_unit)


func _complete_activation_end(ending_unit : UnitRuntime) -> void:
	if battle_state == null or battle_state.is_battle_over:
		return

	if ending_unit != null:
		if status_effect_system != null:
			status_effect_system.finish_activation(
				ending_unit,
				battle_state.turn_state.activation_serial
			)

		_push_event({
			"type": "ActivationEnded",
			"unit_name": ending_unit.data.unit_name
		})

	if battle_state.check_victory_condition():
		return

	_advance_to_next_living_unit()


# ============================================================
# НОВЫЙ РАУНД
# ============================================================

func _start_new_round() -> void:
	if battle_state == null:
		return

	var turn_state: TurnState = (
		battle_state.turn_state
	)

	turn_state.phase = TurnState.Phase.ROUND_START
	turn_state.round_number += 1

	_start_runtime_round(
		turn_state.round_number
	)

	_build_activation_queue()

	turn_state.current_activation_index = -1

	print("")
	print("========================================")
	print(
		"Round ",
		turn_state.round_number,
		" started"
	)
	print("========================================")

	_print_activation_queue()

	_push_event({
		"type": "RoundStarted",
		"round_number": turn_state.round_number
	})

	_advance_to_next_living_unit()

# ============================================================
# ФОРМИРОВАНИЕ ОЧЕРЕДИ АКТИВАЦИЙ
# ============================================================

func _build_activation_queue() -> void:
	if battle_state == null:
		return

	var turn_state: TurnState = (
		battle_state.turn_state
	)

	turn_state.activation_queue.clear()

	for unit in battle_state.units:
		if unit == null:
			continue

		if not unit.is_alive:
			continue

		_roll_initiative_for_unit(unit)

		turn_state.activation_queue.append(
			unit
		)

	turn_state.activation_queue.sort_custom(
		_compare_units_by_initiative_roll
	)
	
func _roll_initiative_for_unit(unit : UnitRuntime) -> void:
	if unit == null:
		return

	if battle_state == null or battle_state.battle_rng == null:
		push_error(
			"TurnPipeline: BattleRng is unavailable for initiative roll"
		)
		return

	var roll_result := battle_state.battle_rng.roll_int(
		RNG_PURPOSE_INITIATIVE_MODIFIER,
		-5,
		5,
		{
			"unit_name": unit.data.unit_name,
			"team_id": unit.team_id,
			"round_number": battle_state.round_number,
			"base_initiative": unit.data.initiative
		}
	)

	if roll_result == null:
		push_error("TurnPipeline: BattleRng initiative roll failed")
		return

	var modifier : int = roll_result.value
	var effect_modifier := 0

	if status_effect_system != null:
		effect_modifier = status_effect_system.get_additive_modifier(
			unit,
			PassiveRuleData.RuleType.MODIFY_INITIATIVE
		)

	unit.set_round_initiative_modifier(modifier, effect_modifier)

	print(
		"Initiative roll | ",
		unit.data.unit_name,
		" | base: ",
		unit.data.initiative,
		" | modifier: ",
		modifier,
		" | effect modifier: ",
		effect_modifier,
		" | total: ",
		unit.initiative_roll_this_round
	)


func _compare_units_by_initiative_roll(unit_a : UnitRuntime, unit_b : UnitRuntime) -> bool:
	if unit_a.initiative_roll_this_round == unit_b.initiative_roll_this_round:
		var effective_base_a := (
			unit_a.data.initiative
			+ unit_a.initiative_effect_modifier_this_round
		)
		var effective_base_b := (
			unit_b.data.initiative
			+ unit_b.initiative_effect_modifier_this_round
		)

		if effective_base_a == effective_base_b:
			if unit_a.team_id == unit_b.team_id:
				return unit_a.data.unit_name < unit_b.data.unit_name

			return unit_a.team_id < unit_b.team_id

		return effective_base_a > effective_base_b

	return unit_a.initiative_roll_this_round > unit_b.initiative_roll_this_round


# ============================================================
# ПЕРЕХОД К СЛЕДУЮЩЕМУ ЮНИТУ
# ============================================================

func _advance_to_next_living_unit() -> void:
	if battle_state == null:
		return

	if battle_state.is_battle_over:
		return

	var turn_state: TurnState = (
		battle_state.turn_state
	)

	turn_state.current_activation_index += 1

	while (
		turn_state.current_activation_index
		< turn_state.activation_queue.size()
	):
		var next_unit: UnitRuntime = (
			turn_state.activation_queue[
				turn_state.current_activation_index
			]
		)

		if _can_unit_activate(next_unit):
			_activate_unit(next_unit)
			return

		turn_state.current_activation_index += 1

	_finish_runtime_round(
		turn_state.round_number
	)

	turn_state.phase = TurnState.Phase.ROUND_END

	_start_new_round()
	
func _can_unit_activate(unit : UnitRuntime) -> bool:
	if unit == null:
		return false

	if not unit.is_alive:
		return false

	if unit.cell == null:
		return false

	return true


# ============================================================
# АКТИВАЦИЯ ЮНИТА
# ============================================================

func _activate_unit(
	unit: UnitRuntime
) -> void:
	if unit == null:
		return

	var turn_state: TurnState = (
		battle_state.turn_state
	)

	turn_state.phase = TurnState.Phase.ACTIVATION
	turn_state.activation_serial += 1

	battle_state.set_active_unit(unit)
	battle_state.clear_pending_ability()
	var movement_modifier := 0

	if status_effect_system != null:
		movement_modifier = status_effect_system.get_additive_modifier(
			unit,
			PassiveRuleData.RuleType.MODIFY_MOVEMENT
		)

	unit.start_activation(
		turn_state.round_number,
		turn_state.current_activation_index,
		movement_modifier
	)

	print("")
	print("----------------------------------------")
	print(
		"Active unit: ",
		unit.data.unit_name
	)
	print(
		"Team: ",
		unit.team_id
	)
	print(
		"Base initiative: ",
		unit.data.initiative
	)
	print(
		"Initiative modifier: ",
		unit.initiative_modifier_this_round
	)
	print(
		"Initiative effect modifier: ",
		unit.initiative_effect_modifier_this_round
	)
	print(
		"Initiative total: ",
		unit.initiative_roll_this_round
	)
	print(
		"AP: ",
		unit.action_points_remaining
	)
	print(
		"MP: ",
		unit.movement_points_remaining
	)
	print("----------------------------------------")

	_push_event({
		"type": "UnitActivated",
		"unit_name": unit.data.unit_name,
		"team_id": unit.team_id,
		"base_initiative": unit.data.initiative,
		"initiative_modifier":
			unit.initiative_modifier_this_round,
		"initiative_total":
			unit.initiative_roll_this_round,
		"round_number": turn_state.round_number,
		"action_points":
			unit.action_points_remaining,
		"movement_points":
			unit.movement_points_remaining,
		"movement_modifier":
			unit.movement_modifier_this_activation,
		"initiative_effect_modifier":
			unit.initiative_effect_modifier_this_round
	})


# ============================================================
# LIFECYCLE RUNTIME-СПОСОБНОСТЕЙ
# ============================================================

func _start_runtime_round(round_number : int) -> void:
	if battle_state == null:
		return

	for unit in battle_state.units:
		if unit != null:
			unit.start_round(round_number)


func _finish_runtime_round(round_number : int) -> void:
	if battle_state == null:
		return

	for unit in battle_state.units:
		if unit != null:
			unit.finish_round(round_number)

	if status_effect_system != null:
		status_effect_system.finish_round(
			battle_state.units,
			round_number
		)

	if impact_executor != null:
		impact_executor.finish_battlefield_object_round(
			round_number,
			battle_state
		)

# ============================================================
# ОТЛАДКА ОЧЕРЕДИ
# ============================================================

func _print_activation_queue() -> void:
	if battle_state == null:
		return

	var turn_state: TurnState = (
		battle_state.turn_state
	)

	print("Activation queue:")

	for unit in turn_state.activation_queue:
		if unit == null:
			continue

		print(
			unit.data.unit_name,
			" | team: ",
			unit.team_id,
			" | base initiative: ",
			unit.data.initiative,
			" | modifier: ",
			unit.initiative_modifier_this_round,
			" | effect modifier: ",
			unit.initiative_effect_modifier_this_round,
			" | total: ",
			unit.initiative_roll_this_round
		)
# ============================================================
# EVENT QUEUE
# ============================================================

func _push_event(event : Dictionary) -> void:
	if event_queue == null:
		return

	event_queue.push_event(event)
	
