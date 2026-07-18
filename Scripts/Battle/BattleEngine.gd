extends Node

class_name BattleEngine


# ============================================================
# КОНСТАНТЫ TARGET RULES
# ============================================================

const TARGET_RULE_AREA_AROUND_CELL : String = "area_around_cell"


# ============================================================
# ТЕСТОВЫЕ DATA-РЕСУРСЫ
# ============================================================

@export var archer_data : UnitData
@export var defense_dummy_data : UnitData
@export var armor_dummy_data : UnitData

@export var longbow_shot : UnitAbilityData


# ============================================================
# УЗЛЫ BATTLE ENGINE
# ============================================================

@onready var battle_initializer : BattleInitializer = $BattleInitializer
@onready var command_dispatcher : CommandDispatcher = $CommandDispatcher
@onready var pipeline_runner : PipelineRunner = $PipelineRunner
@onready var event_queue : EventQueue = $EventQueue

@onready var ability_pipeline : AbilityPipeline = $Pipelines/AbilityPipeline
@onready var movement_pipeline : MovementPipeline = $Pipelines/MovementPipeline
@onready var turn_pipeline : TurnPipeline = $Pipelines/TurnPipeline

# ============================================================
# УЗЛЫ СЦЕНЫ
# ============================================================

@onready var battlefield_view : BattlefieldView = $"../Battlefield"
@onready var ability_panel : AbilityPanel = $"../UI/AbilityPanel"
@onready var end_turn_button : Button = $"../UI/EndTurnButton"

# ============================================================
# RUNTIME-СОСТОЯНИЕ БОЯ
# ============================================================

var battle_state : BattleState = null


# ============================================================
# ИНИЦИАЛИЗАЦИЯ
# ============================================================

func _ready() -> void:
	if not _validate_resources():
		return

	_create_battle_state()
	_configure_pipelines()
	_initialize_test_battle()

	turn_pipeline.start_battle_flow()

	_connect_view_and_ui()
	_refresh_views()

	print("")
	print("BattleEngine ready")
	print("BattleState cells count: ", battle_state.cells.size())
	print("BattleState units count: ", battle_state.units.size())


func _configure_pipelines() -> void:
	ability_pipeline.configure(battle_state)

	pipeline_runner.configure(
		ability_pipeline,
		movement_pipeline,
		event_queue
	)

	movement_pipeline.configure(
		battle_state,
		event_queue
	)
	
	turn_pipeline.configure(
		battle_state,
		event_queue
)

	command_dispatcher.configure(
		battle_state,
		pipeline_runner
	)


func _initialize_test_battle() -> void:
	battle_initializer.initialize_test_battle(
		battle_state,
		archer_data,
		defense_dummy_data,
		armor_dummy_data
	)


# ============================================================
# ПРОВЕРКА РЕСУРСОВ И УЗЛОВ
# ============================================================

func _validate_resources() -> bool:
	var is_valid : bool = true

	if archer_data == null:
		push_error("BattleEngine: archer_data is not assigned")
		is_valid = false

	if defense_dummy_data == null:
		push_error("BattleEngine: defense_dummy_data is not assigned")
		is_valid = false

	if armor_dummy_data == null:
		push_error("BattleEngine: armor_dummy_data is not assigned")
		is_valid = false

	if longbow_shot == null:
		push_error("BattleEngine: longbow_shot is not assigned")
		is_valid = false

	if battle_initializer == null:
		push_error("BattleEngine: BattleInitializer node is missing or has no BattleInitializer script")
		is_valid = false

	if command_dispatcher == null:
		push_error("BattleEngine: CommandDispatcher node is missing or has no CommandDispatcher script")
		is_valid = false

	if pipeline_runner == null:
		push_error("BattleEngine: PipelineRunner node is missing or has no PipelineRunner script")
		is_valid = false

	if event_queue == null:
		push_error("BattleEngine: EventQueue node is missing or has no EventQueue script")
		is_valid = false

	if ability_pipeline == null:
		push_error("BattleEngine: AbilityPipeline node is missing or has no AbilityPipeline script")
		is_valid = false

	if movement_pipeline == null:
		push_error("BattleEngine: MovementPipeline node is missing or has no MovementPipeline script")
		is_valid = false

	if turn_pipeline == null:
		push_error("BattleEngine: TurnPipeline node is missing or has no TurnPipeline script")
		is_valid = false
	
	if battlefield_view == null:
		push_error("BattleEngine: Battlefield node is missing or has no BattlefieldView script")
		is_valid = false

	if ability_panel == null:
		push_error("BattleEngine: AbilityPanel node is missing or has no AbilityPanel script")
		is_valid = false
	
	if end_turn_button == null:
		push_error("BattleEngine: EndTurnButton node is missing")
		is_valid = false
	return is_valid


# ============================================================
# СОЗДАНИЕ СОСТОЯНИЯ БОЯ
# ============================================================

func _create_battle_state() -> void:
	battle_state = BattleState.new()

	battle_state.generate_battlefield()
	battle_state.print_battlefield_zones()


# ============================================================
# СВЯЗЬ VIEW И UI
# ============================================================

func _connect_view_and_ui() -> void:
	ability_panel.ability_selected.connect(_on_ability_selected)
	battlefield_view.cell_clicked.connect(_on_cell_clicked)
	end_turn_button.pressed.connect(_on_end_turn_pressed)

# ============================================================
# ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ
# ============================================================

func _refresh_views() -> void:
	battlefield_view.draw_battlefield(battle_state)
	ability_panel.show_unit_abilities(battle_state.active_unit)


# ============================================================
# ПРАВЫЙ КЛИК: СБРОС ВЫБРАННОЙ СПОСОБНОСТИ
# ============================================================

func _unhandled_input(event : InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_cancel_pending_ability()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				_end_current_activation()
				get_viewport().set_input_as_handled()
				return

func _cancel_pending_ability() -> void:
	if battle_state == null:
		return

	if battle_state.pending_ability == null:
		return

	print("Ability selection cancelled")

	battle_state.clear_pending_ability()

	if battlefield_view != null:
		battlefield_view.set_targeting(false, null)

	_refresh_views()


# ============================================================
# ЗАВЕРШЕНИЕ КЛИКА СПОСОБНОСТИ
# ============================================================

func _finish_ability_click() -> void:
	if battle_state == null:
		return

	battle_state.clear_pending_ability()

	if battlefield_view != null:
		battlefield_view.set_targeting(false, null)

	battle_state.check_victory_condition()

	_refresh_views()
func _end_current_activation() -> void:
	if battle_state == null:
		return

	if battle_state.is_battle_over:
		print("BattleEngine: battle is over, cannot end activation")
		return

	if battle_state.pending_ability != null:
		battle_state.clear_pending_ability()

		if battlefield_view != null:
			battlefield_view.set_targeting(false, null)

	turn_pipeline.end_current_activation()

	_refresh_views()

func _on_end_turn_pressed() -> void:
	_end_current_activation()
	
# ============================================================
# ВЫБОР СПОСОБНОСТИ
# ============================================================

func _on_ability_selected(unit_ability : UnitAbilityData) -> void:
	if battle_state == null:
		push_error("BattleEngine: battle_state is null")
		return

	if battle_state.is_battle_over:
		print("BattleEngine: battle is over, ability selection ignored")
		return

	if unit_ability == null:
		push_error("BattleEngine: selected ability is null")
		return
	if battle_state.active_unit == null:
		push_error("BattleEngine: active_unit is null")
		return

	if not battle_state.active_unit.can_spend_action_points(1):
		print("BattleEngine: active unit has no action points")
		return
		
	battle_state.set_pending_ability(unit_ability)

	battlefield_view.set_targeting(true, battle_state.active_unit)
	battlefield_view.draw_battlefield(battle_state)

	print("")
	print("Ability selected: ", unit_ability.ability_name)
	print("Choose target on battlefield")


# ============================================================
# КЛИК ПО КЛЕТКЕ
# ============================================================

func _on_cell_clicked(cell : CellRuntime) -> void:
	if cell == null:
		return

	if battle_state == null:
		push_error("BattleEngine: battle_state is null")
		return

	if battle_state.is_battle_over:
		print("BattleEngine: battle is over, input ignored")
		return

	if battle_state.active_unit == null:
		push_error("BattleEngine: active_unit is null")
		return

	var target_unit : UnitRuntime = battle_state.get_unit_on_cell(cell)

	if battle_state.pending_ability == null:
		_handle_movement_click(cell, target_unit)
		return

	_handle_ability_click(cell, target_unit)


# ============================================================
# КЛИК В РЕЖИМЕ ДВИЖЕНИЯ
# ============================================================

func _handle_movement_click(cell : CellRuntime, target_unit : UnitRuntime) -> void:
	if target_unit != null:
		print("Cannot move to occupied cell: ", cell.x, ",", cell.y)
		return

	command_dispatcher.dispatch_command({
		"type": "move_unit",
		"unit": battle_state.active_unit,
		"target_cell": cell
	})

	_refresh_views()


# ============================================================
# КЛИК В РЕЖИМЕ ВЫБРАННОЙ СПОСОБНОСТИ
# ============================================================

func _handle_ability_click(cell : CellRuntime, target_unit : UnitRuntime) -> void:
	var pending_ability : UnitAbilityData = battle_state.pending_ability

	if pending_ability == null:
		push_error("BattleEngine: pending_ability is null")
		return

	if pending_ability.ability == null:
		push_error("BattleEngine: pending_ability has no AbilityData")
		return

	var target_rule_id : String = pending_ability.ability.target_rule_id

	_print_ability_click_debug(cell, target_unit, pending_ability, target_rule_id)

	if target_rule_id == TARGET_RULE_AREA_AROUND_CELL:
		_dispatch_use_ability(cell, target_unit, pending_ability)
		_finish_ability_click()
		return

	if target_unit == null:
		print("Clicked empty cell while ability requires unit target: ", cell.x, ",", cell.y)
		return

	_dispatch_use_ability(cell, target_unit, pending_ability)
	_finish_ability_click()


func _dispatch_use_ability(
	cell : CellRuntime,
	target_unit : UnitRuntime,
	pending_ability : UnitAbilityData
) -> void:
	command_dispatcher.dispatch_command({
		"type": "use_ability",
		"source_unit": battle_state.active_unit,
		"target_unit": target_unit,
		"target_cell": cell,
		"unit_ability": pending_ability
	})


func _print_ability_click_debug(
	cell : CellRuntime,
	target_unit : UnitRuntime,
	pending_ability : UnitAbilityData,
	target_rule_id : String
) -> void:
	var target_name : String = "none"

	if target_unit != null:
		target_name = target_unit.data.unit_name

	print(
		"BattleEngine ability click | ability: ",
		pending_ability.ability_name,
		" | target_rule_id: ",
		target_rule_id,
		" | cell: ",
		cell.x,
		",",
		cell.y,
		" | target_unit: ",
		target_name
	)
	
