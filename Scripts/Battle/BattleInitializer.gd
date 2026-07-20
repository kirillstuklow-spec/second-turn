extends Node

class_name BattleInitializer


# ============================================================
# ИНИЦИАЛИЗАЦИЯ ТЕСТОВОГО БОЯ
# ============================================================

func initialize_test_battle(
	battle_state: BattleState,
	first_player_unit_data: UnitData,
	second_player_unit_data: UnitData,
	defense_dummy_data: UnitData,
	armor_dummy_data: UnitData
) -> void:
	print(
		"BattleInitializer: initialize_test_battle called"
	)

	var first_player_unit: UnitRuntime = (
		battle_state.spawn_unit(
			first_player_unit_data,
			1,
			0,
			2
		)
	)

	battle_state.spawn_unit(
		second_player_unit_data,
		1,
		0,
		3
	)

	battle_state.spawn_unit(
		defense_dummy_data,
		2,
		6,
		2
	)

	battle_state.spawn_unit(
		armor_dummy_data,
		2,
		6,
		3
	)

	if first_player_unit != null:
		battle_state.set_active_unit(
			first_player_unit
		)

	battle_state.print_units()
	
