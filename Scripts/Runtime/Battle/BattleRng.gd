extends RefCounted

class_name BattleRng


const AUTO_SEED : int = 0


var initial_seed : int = 1

var roll_history : Array[BattleRngRollResult] = []

var current_state : int:
	get:
		return _generator.state


var _generator : RandomNumberGenerator = RandomNumberGenerator.new()

var _next_roll_sequence : int = 1


func _init(seed_value : int = AUTO_SEED) -> void:
	configure(seed_value)


# ============================================================
# SEED И STATE
# ============================================================

func configure(seed_value : int = AUTO_SEED) -> void:
	initial_seed = seed_value

	if initial_seed == AUTO_SEED:
		initial_seed = _generate_auto_seed()

	_generator.seed = initial_seed
	roll_history.clear()
	_next_roll_sequence = 1


func reset_to_initial_seed() -> void:
	_generator.seed = initial_seed
	roll_history.clear()
	_next_roll_sequence = 1


func restore_state(saved_state : int) -> void:
	_generator.state = saved_state


func clear_history() -> void:
	roll_history.clear()


# ============================================================
# ЕДИНСТВЕННЫЙ ВХОД ДЛЯ ЦЕЛОЧИСЛЕННОГО БРОСКА
# ============================================================

func roll_int(
	purpose : StringName,
	minimum_value : int,
	maximum_value : int,
	context : Dictionary = {}
) -> BattleRngRollResult:
	if purpose == &"":
		push_error("BattleRng: purpose must not be empty")
		return null

	if minimum_value > maximum_value:
		push_error(
			"BattleRng: minimum_value is greater than maximum_value"
		)
		return null

	var state_before := _generator.state
	var rolled_value := _generator.randi_range(
		minimum_value,
		maximum_value
	)
	var state_after := _generator.state
	var sequence_number := _next_roll_sequence
	var roll_id := StringName(
		"battle_rng_roll_%06d" % sequence_number
	)

	_next_roll_sequence += 1

	var result := BattleRngRollResult.create(
		roll_id,
		sequence_number,
		purpose,
		minimum_value,
		maximum_value,
		rolled_value,
		state_before,
		state_after,
		context
	)

	roll_history.append(result)
	return result


func _generate_auto_seed() -> int:
	var generated_seed := hash([
		Time.get_ticks_usec(),
		Time.get_unix_time_from_system()
	])

	if generated_seed == AUTO_SEED:
		return 1

	return generated_seed

