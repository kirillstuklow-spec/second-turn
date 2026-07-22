extends PanelContainer
class_name InitiativeQueuePanel


# ============================================================
# ВНУТРЕННИЕ УЗЛЫ
# ============================================================

@onready var round_label: Label = (
	$MarginContainer/ContentColumn/RoundLabel
)

@onready var queue_row: HBoxContainer = (
	$MarginContainer/ContentColumn/QueueScroll/QueueRow
)


# ============================================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================================

func _ready() -> void:
	clear_panel()


# ============================================================
# ОТОБРАЖЕНИЕ СОСТОЯНИЯ ХОДОВ
# ============================================================

func show_turn_state(
	turn_state: TurnState
) -> void:
	if turn_state == null:
		clear_panel()
		return

	round_label.text = "Раунд %d" % (
		turn_state.round_number
	)

	_clear_queue_entries()

	for queue_index in range(
		turn_state.activation_queue.size()
	):
		var unit: UnitRuntime = (
			turn_state.activation_queue[
				queue_index
			]
		)

		if unit == null:
			continue

		if unit.data == null:
			push_warning(
				"InitiativeQueuePanel: "
				+ "UnitRuntime has no UnitData"
			)
			continue

		var is_current_unit: bool = (
			queue_index
			== turn_state.current_activation_index
		)

		_create_queue_entry(
			unit,
			is_current_unit
		)


# ============================================================
# СОЗДАНИЕ ЭЛЕМЕНТА ОЧЕРЕДИ
# ============================================================

func _create_queue_entry(
	unit: UnitRuntime,
	is_current_unit: bool
) -> void:
	if unit == null:
		return

	if unit.data == null:
		return

	var entry_panel := PanelContainer.new()

	entry_panel.custom_minimum_size = Vector2(
		130,
		58
	)

	var entry_label := Label.new()

	entry_label.horizontal_alignment = (
		HORIZONTAL_ALIGNMENT_CENTER
	)

	entry_label.vertical_alignment = (
		VERTICAL_ALIGNMENT_CENTER
	)

	entry_label.size_flags_horizontal = (
		Control.SIZE_EXPAND_FILL
	)

	entry_label.size_flags_vertical = (
		Control.SIZE_EXPAND_FILL
	)

	var state_marker: String = ""

	if not unit.is_alive:
		state_marker = "† "
	elif is_current_unit:
		state_marker = "▶ "

	entry_label.text = (
		"%s%s\nКоманда %d · Иниц. %d"
		% [
			state_marker,
			unit.data.unit_name,
			unit.team_id,
			unit.initiative_roll_this_round
		]
	)

	entry_panel.add_child(
		entry_label
	)

	queue_row.add_child(
		entry_panel
	)


# ============================================================
# ОЧИСТКА ЭЛЕМЕНТОВ ОЧЕРЕДИ
# ============================================================

func _clear_queue_entries() -> void:
	if queue_row == null:
		return

	for child in queue_row.get_children():
		queue_row.remove_child(
			child
		)

		child.queue_free()


# ============================================================
# ОЧИСТКА ПАНЕЛИ
# ============================================================

func clear_panel() -> void:
	if round_label != null:
		round_label.text = "Раунд —"

	_clear_queue_entries()
