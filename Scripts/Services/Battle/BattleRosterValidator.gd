extends RefCounted

class_name BattleRosterValidator


const MIN_UNITS_PER_TEAM : int = 1
const MAX_UNITS_PER_TEAM : int = 6
const MAX_TOTAL_UNITS : int = 12


static func validate(
	player_1_units : Array[UnitData],
	player_2_units : Array[UnitData],
	arena_data : ArenaData = null
) -> Dictionary:
	var errors := PackedStringArray()
	var player_1_capacity := MAX_UNITS_PER_TEAM
	var player_2_capacity := MAX_UNITS_PER_TEAM

	if arena_data != null:
		player_1_capacity = arena_data.player_1_deployment_capacity
		player_2_capacity = arena_data.player_2_deployment_capacity

	_validate_team(
		player_1_units,
		1,
		player_1_capacity,
		errors
	)
	_validate_team(
		player_2_units,
		2,
		player_2_capacity,
		errors
	)

	if player_1_units.size() + player_2_units.size() > MAX_TOTAL_UNITS:
		errors.append(
			"Совокупный размер составов не может превышать %d юнитов."
			% MAX_TOTAL_UNITS
		)

	return {
		"is_valid": errors.is_empty(),
		"errors": errors
	}


static func _validate_team(
	units : Array[UnitData],
	team_id : int,
	deployment_capacity : int,
	errors : PackedStringArray
) -> void:
	if units.size() < MIN_UNITS_PER_TEAM:
		errors.append(
			"В команде %d должен быть хотя бы один юнит." % team_id
		)

	if units.size() > MAX_UNITS_PER_TEAM:
		errors.append(
			"В команде %d не может быть больше %d юнитов."
			% [team_id, MAX_UNITS_PER_TEAM]
		)

	if units.size() > deployment_capacity:
		errors.append(
			(
				"Состав команды %d содержит %d юнитов, но зона "
				+ "расстановки вмещает только %d."
			)
			% [team_id, units.size(), deployment_capacity]
		)

	for unit_index in range(units.size()):
		if units[unit_index] == null:
			errors.append(
				"Команда %d: UnitData в позиции %d не назначен."
				% [team_id, unit_index + 1]
			)
