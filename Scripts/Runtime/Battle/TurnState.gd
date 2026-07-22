extends RefCounted
class_name TurnState


# ============================================================
# ФАЗЫ СИСТЕМЫ ХОДОВ
# ============================================================

enum Phase {
	NOT_STARTED,
	ROUND_START,
	ACTIVATION,
	ROUND_END,
	BATTLE_END
}


# ============================================================
# СОСТОЯНИЕ РАУНДА
# ============================================================

var round_number: int = 0

var phase: Phase = Phase.NOT_STARTED


# ============================================================
# ОЧЕРЕДЬ АКТИВАЦИЙ
# ============================================================

var activation_queue: Array[UnitRuntime] = []

var current_activation_index: int = -1


# ============================================================
# АКТИВНЫЙ ЮНИТ
# ============================================================

var active_unit: UnitRuntime = null


# ============================================================
# ОЧИСТКА СОСТОЯНИЯ
# ============================================================

func clear() -> void:
	round_number = 0
	phase = Phase.NOT_STARTED

	activation_queue.clear()
	current_activation_index = -1

	active_unit = null
