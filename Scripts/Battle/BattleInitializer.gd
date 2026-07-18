extends Node

class_name BattleInitializer


func initialize_test_battle(
	battle_state: BattleState,
	archer_data: UnitData,
	defense_dummy_data: UnitData,
	armor_dummy_data: UnitData
) -> void:
	print("BattleInitializer: initialize_test_battle called")

	var archer : UnitRuntime = battle_state.spawn_unit(archer_data, 1, 0, 2)

	battle_state.spawn_unit(defense_dummy_data, 2, 6, 2)
	battle_state.spawn_unit(armor_dummy_data, 2, 6, 3)

	if archer != null:
		battle_state.set_active_unit(archer)

	battle_state.print_units()
