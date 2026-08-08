extends RefCounted

class_name TargetingResult


enum Reason {
	NONE,
	BATTLE_STATE_MISSING,
	SOURCE_MISSING,
	ABILITY_MISSING,
	SOURCE_NOT_IN_BATTLE,
	SOURCE_NOT_ALIVE,
	TARGET_RULE_UNSUPPORTED,
	TARGET_UNIT_REQUIRED,
	TARGET_CELL_REQUIRED,
	TARGET_UNIT_NOT_IN_BATTLE,
	TARGET_CELL_NOT_IN_BATTLE,
	TARGET_UNIT_CELL_MISMATCH,
	TARGET_NOT_ALIVE,
	TARGET_NOT_ENEMY,
	TARGET_NOT_ALLY,
	TARGET_NOT_ADJACENT,
	TARGET_CELL_OCCUPIED,
	TARGET_CELL_WRONG_ZONE,
	NO_VALID_TARGETS,
	CONDITION_FAILED
}


var is_valid : bool = true

var reason : Reason = Reason.NONE

var context : Dictionary = {}

var snapshot : BattleStateSnapshot = null

var source_snapshot : UnitStateSnapshot = null

var selected_unit_snapshot : UnitStateSnapshot = null

var selected_cell_snapshot : CellStateSnapshot = null

var target_unit_snapshots : Array[UnitStateSnapshot] = []

var target_cell_snapshots : Array[CellStateSnapshot] = []


func reject(
	rejection_reason : Reason,
	rejection_context : Dictionary = {}
) -> TargetingResult:
	is_valid = false
	reason = rejection_reason
	context = rejection_context.duplicate(true)
	return self


func get_target_units() -> Array[UnitRuntime]:
	var targets : Array[UnitRuntime] = []

	for unit_snapshot in target_unit_snapshots:
		if unit_snapshot != null and unit_snapshot.unit != null:
			targets.append(unit_snapshot.unit)

	return targets


func get_target_cells() -> Array[CellRuntime]:
	var targets : Array[CellRuntime] = []

	for cell_snapshot in target_cell_snapshots:
		if cell_snapshot != null and cell_snapshot.cell != null:
			targets.append(cell_snapshot.cell)

	return targets


func get_summary() -> String:
	match reason:
		Reason.NONE:
			return "Цели способности определены."

		Reason.BATTLE_STATE_MISSING:
			return "Состояние боя отсутствует."

		Reason.SOURCE_MISSING:
			return "Источник способности отсутствует."

		Reason.ABILITY_MISSING:
			return "Данные способности отсутствуют."

		Reason.SOURCE_NOT_IN_BATTLE:
			return "Источник не зарегистрирован в текущем бою."

		Reason.SOURCE_NOT_ALIVE:
			return "Источник способности не является живым."

		Reason.TARGET_RULE_UNSUPPORTED:
			return "Неизвестное правило цели: '%s'." % str(
				context.get("target_rule_id", "")
			)

		Reason.TARGET_UNIT_REQUIRED:
			return "Для способности требуется цель-юнит."

		Reason.TARGET_CELL_REQUIRED:
			return "Для способности требуется цель-клетка."

		Reason.TARGET_UNIT_NOT_IN_BATTLE:
			return "Выбранный юнит не зарегистрирован в текущем бою."

		Reason.TARGET_CELL_NOT_IN_BATTLE:
			return "Выбранная клетка не принадлежит текущему полю."

		Reason.TARGET_UNIT_CELL_MISMATCH:
			return "Выбранные юнит и клетка не соответствуют друг другу."

		Reason.TARGET_NOT_ALIVE:
			return "Выбранный юнит не является живым."

		Reason.TARGET_NOT_ENEMY:
			return "Атакующая способность требует вражескую цель."

		Reason.TARGET_NOT_ALLY:
			return "Способность требует союзную цель."

		Reason.TARGET_NOT_ADJACENT:
			return "Цель не находится на соседней ортогональной клетке."

		Reason.TARGET_CELL_OCCUPIED:
			return "Выбранная клетка занята."

		Reason.TARGET_CELL_WRONG_ZONE:
			return "Выбранная клетка не относится к зоне расстановки владельца."

		Reason.NO_VALID_TARGETS:
			return "В выбранной области нет допустимых целей."

		Reason.CONDITION_FAILED:
			return "Не выполнено условие цели: '%s'." % str(
				context.get("condition_id", "")
			)

	return "Цель способности отклонена."
