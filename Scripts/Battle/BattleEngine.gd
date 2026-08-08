extends Node
class_name BattleEngine

# ============================================================
# СИГНАЛЫ ПРЕДСТАВЛЕНИЯ
# ============================================================

signal presentation_refresh_requested(
	active_unit: UnitRuntime,
	availability_results: Array[AbilityAvailabilityResult]
)

signal turn_state_refresh_requested(
	turn_state: TurnState
)

# ============================================================
# КОНСТАНТЫ TARGET RULES
# ============================================================

const TARGET_RULE_AREA_AROUND_CELL: String = "area_around_cell"

const TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL: String = (
	"single_empty_deployment_cell"
)


# ============================================================
# ТЕСТОВАЯ КОНФИГУРАЦИЯ БОЯ
# ============================================================

@export var arena_data: ArenaData

# Размер массива определяет число юнитов. Один UnitData допустимо указать
# несколько раз: для каждой записи будет создан независимый UnitRuntime.
@export var player_1_units: Array[UnitData] = []

@export var player_2_units: Array[UnitData] = []

# Ноль создаёт новый seed автоматически. Ненулевое значение позволяет
# дословно воспроизвести последовательность боевых бросков.
@export var battle_seed: int = BattleRng.AUTO_SEED

# ============================================================
# ВНУТРЕННИЕ УЗЛЫ BATTLE ENGINE
# ============================================================

@onready var battle_initializer: BattleInitializer = (
	$BattleInitializer
)

@onready var command_dispatcher: CommandDispatcher = (
	$CommandDispatcher
)

@onready var pipeline_runner: PipelineRunner = (
	$PipelineRunner
)

@onready var event_queue: EventQueue = (
	$EventQueue
)

@onready var ability_pipeline: AbilityPipeline = (
	$Pipelines/AbilityPipeline
)

@onready var movement_pipeline: MovementPipeline = (
	$Pipelines/MovementPipeline
)

@onready var turn_pipeline: TurnPipeline = (
	$Pipelines/TurnPipeline
)

@onready var decision_pipeline: DecisionPipeline = (
	$Pipelines/DecisionPipeline
)


# ============================================================
# ВНЕШНИЕ ЗАВИСИМОСТИ
# ============================================================

# Эти ссылки передаёт BattleScene.
# BattleEngine больше не ищет соседние узлы самостоятельно.

var battlefield_view: BattlefieldView = null


# ============================================================
# RUNTIME-СОСТОЯНИЕ БОЯ
# ============================================================

var battle_state: BattleState = null

var ability_algorithm_registry := AbilityAlgorithmRegistry.new()

var ability_availability_service := AbilityAvailabilityService.new()

var targeting_service := TargetingService.new()

var ability_impact_plan_builder := AbilityImpactPlanBuilder.new()

var interaction_resolver := InteractionResolver.new()

var status_effect_system := StatusEffectSystem.new()

var combat_event_log := CombatEventLog.new()

var reaction_queue := ReactionQueue.new()

var reaction_system := ReactionSystem.new()

var death_resolver := DeathResolver.new()

var impact_condition_evaluator := ImpactConditionEvaluator.new()

var impact_executor := ImpactExecutor.new()

var _is_initialized: bool = false


# ============================================================
# ОЧИСТКА ПРИ ЗАКРЫТИИ БОЕВОЙ СЦЕНЫ
# ============================================================

func _exit_tree() -> void:
	if battle_state == null:
		return

	battle_state.clear()
	battle_state = null


# ============================================================
# ПУБЛИЧНАЯ ИНИЦИАЛИЗАЦИЯ
# ============================================================

func initialize(
	new_battlefield_view: BattlefieldView
) -> bool:
	if _is_initialized:
		push_warning(
			"BattleEngine: initialize() was called more than once"
		)
		return true

	battlefield_view = new_battlefield_view

	if not _validate_configuration():
		return false

	_create_battle_state()
	_configure_pipelines()
	if not _initialize_test_battle():
		battle_state.clear()
		battle_state = null
		return false
	_connect_view_and_ui()

	turn_pipeline.start_battle_flow()

	_is_initialized = true

	_refresh_views()

	print("")
	print("BattleEngine ready")
	print(
		"BattleState cells count: ",
		battle_state.cells.size()
	)
	print(
		"BattleState units count: ",
		battle_state.units.size()
	)

	return true

func _configure_pipelines() -> void:
	ability_availability_service.set_algorithm_registry(
		ability_algorithm_registry
	)

	reaction_system.configure(
		reaction_queue,
		ability_impact_plan_builder,
		targeting_service
	)

	impact_executor.configure(
		interaction_resolver,
		status_effect_system,
		combat_event_log,
		reaction_queue,
		reaction_system,
		impact_condition_evaluator,
		ability_impact_plan_builder,
		death_resolver
	)

	ability_pipeline.configure(
		battle_state,
		ability_availability_service,
		ability_algorithm_registry,
		targeting_service,
		ability_impact_plan_builder,
		impact_executor
	)

	movement_pipeline.configure(
		battle_state,
		event_queue
	)

	turn_pipeline.configure(
		battle_state,
		event_queue,
		status_effect_system,
		impact_executor
	)

	decision_pipeline.configure(
		battle_state,
		impact_executor
	)

	pipeline_runner.configure(
		ability_pipeline,
		movement_pipeline,
		turn_pipeline,
		event_queue,
		decision_pipeline
	)

	command_dispatcher.configure(
		battle_state,
		pipeline_runner
	)


# ============================================================
# ИНИЦИАЛИЗАЦИЯ ТЕСТОВОГО БОЯ
# ============================================================

func _initialize_test_battle() -> bool:
	return battle_initializer.initialize_test_battle(
		battle_state,
		player_1_units,
		player_2_units
	)
	
# ============================================================
# ПРОВЕРКА КОНФИГУРАЦИИ
# ============================================================

func _validate_configuration() -> bool:
	var is_valid: bool = true

	if arena_data != null:
		var arena_validation := ArenaValidator.validate(
			arena_data
		)

		for warning in arena_validation["warnings"]:
			push_warning(
				"BattleEngine: ArenaData: " + str(warning)
			)

		for error in arena_validation["errors"]:
			push_error(
				"BattleEngine: ArenaData: " + str(error)
			)
			is_valid = false

	var roster_validation := BattleRosterValidator.validate(
		player_1_units,
		player_2_units,
		arena_data
	)

	for error in roster_validation["errors"]:
		push_error("BattleEngine: roster: " + str(error))
		is_valid = false

	is_valid = (
		_validate_roster_ability_schemas(
			player_1_units,
			"player_1_units"
		)
		and is_valid
	)
	is_valid = (
		_validate_roster_ability_schemas(
			player_2_units,
			"player_2_units"
		)
		and is_valid
	)

	if battle_initializer == null:
		push_error(
			"BattleEngine: BattleInitializer node is missing "
			+ "or has no BattleInitializer script"
		)
		is_valid = false

	if command_dispatcher == null:
		push_error(
			"BattleEngine: CommandDispatcher node is missing "
			+ "or has no CommandDispatcher script"
		)
		is_valid = false

	if pipeline_runner == null:
		push_error(
			"BattleEngine: PipelineRunner node is missing "
			+ "or has no PipelineRunner script"
		)
		is_valid = false

	if event_queue == null:
		push_error(
			"BattleEngine: EventQueue node is missing "
			+ "or has no EventQueue script"
		)
		is_valid = false

	if ability_pipeline == null:
		push_error(
			"BattleEngine: AbilityPipeline node is missing "
			+ "or has no AbilityPipeline script"
		)
		is_valid = false

	if movement_pipeline == null:
		push_error(
			"BattleEngine: MovementPipeline node is missing "
			+ "or has no MovementPipeline script"
		)
		is_valid = false

	if turn_pipeline == null:
		push_error(
			"BattleEngine: TurnPipeline node is missing "
			+ "or has no TurnPipeline script"
		)
		is_valid = false

	if decision_pipeline == null:
		push_error(
			"BattleEngine: DecisionPipeline node is missing "
			+ "or has no DecisionPipeline script"
		)
		is_valid = false

	if battlefield_view == null:
		push_error(
			"BattleEngine: BattlefieldView was not provided "
			+ "by BattleScene"
		)
		is_valid = false

	return is_valid


func _validate_roster_ability_schemas(
	roster: Array[UnitData],
	field_name: String
) -> bool:
	var is_valid := true

	for unit_index in range(roster.size()):
		var unit_data := roster[unit_index]

		if unit_data == null:
			continue

		if not _validate_unit_ability_schemas(
			unit_data,
			"%s[%d]" % [field_name, unit_index]
		):
			is_valid = false

	return is_valid


func _validate_unit_ability_schemas(
	unit_data: UnitData,
	field_name: String
) -> bool:
	var is_valid := true
	var ability_index := 0

	for unit_ability in unit_data.active_abilities:
		if not _validate_ability_schema(
			unit_ability,
			"%s.active_abilities[%d]" % [
				field_name,
				ability_index
			]
		):
			is_valid = false

		ability_index += 1

	ability_index = 0

	for unit_ability in unit_data.passive_abilities:
		if not _validate_ability_schema(
			unit_ability,
			"%s.passive_abilities[%d]" % [
				field_name,
				ability_index
			]
		):
			is_valid = false

		ability_index += 1

	return is_valid


func _validate_ability_schema(
	unit_ability: UnitAbilityData,
	field_path: String
) -> bool:
	var schema_result := ability_algorithm_registry.validate_unit_ability(
		unit_ability
	)

	if schema_result.is_valid:
		return true

	push_error(
		"BattleEngine: invalid ability schema at %s:\n%s" % [
			field_path,
			schema_result.get_summary()
		]
	)

	return false
	

# ============================================================
# СОЗДАНИЕ СОСТОЯНИЯ БОЯ
# ============================================================

func _create_battle_state() -> void:
	status_effect_system.clear_runtime_sequence()
	combat_event_log.clear()
	reaction_queue.clear()
	death_resolver.clear()

	battle_state = BattleState.new()
	battle_state.configure_battle_rng(battle_seed)
	battle_state.generate_battlefield(
		arena_data
	)
	print(
		"Battle RNG seed: ",
		battle_state.battle_rng.initial_seed
	)
	battle_state.print_battlefield_zones()


# ============================================================
# СВЯЗЬ С ПРЕДСТАВЛЕНИЕМ
# ============================================================

func _connect_view_and_ui() -> void:
	var cell_callback := Callable(
		self,
		"_on_cell_clicked"
	)

	if not battlefield_view.cell_clicked.is_connected(
		cell_callback
	):
		battlefield_view.cell_clicked.connect(
			cell_callback
		)

# ============================================================
# ПУБЛИЧНЫЕ НАМЕРЕНИЯ
# ============================================================

func request_end_turn() -> void:
	if not _is_initialized:
		push_error(
			"BattleEngine: cannot end turn before initialization"
		)
		return

	if battle_state != null and battle_state.pending_decision != null:
		print("BattleEngine: resolve the pending decision first")
		return

	_end_current_activation()

# ============================================================
# ПУБЛИЧНЫЙ ЗАПРОС ВЫБОРА СПОСОБНОСТИ
# ============================================================

func request_ability_selection(
	ability_runtime: UnitAbilityRuntime
) -> void:
	if not _is_initialized:
		push_error(
			"BattleEngine: cannot select ability "
			+ "before initialization"
		)
		return

	if battle_state != null and battle_state.pending_decision != null:
		print("BattleEngine: ability selection blocked by pending decision")
		return

	if ability_runtime == null:
		push_error(
			"BattleEngine: selected ability is null"
		)
		return

	_on_ability_selected(
		ability_runtime
	)
	
# ============================================================
# ОБНОВЛЕНИЕ ОТОБРАЖЕНИЯ
# ============================================================

func _refresh_views() -> void:
	if battle_state == null:
		push_error(
			"BattleEngine: cannot refresh views "
			+ "because battle_state is null"
		)
		return

	if battlefield_view != null:
		battlefield_view.draw_battlefield(
			battle_state
		)

	var availability_results := (
		_build_ability_availability_results(
			battle_state.active_unit
		)
	)

	presentation_refresh_requested.emit(
		battle_state.active_unit,
		availability_results
	)

	turn_state_refresh_requested.emit(
		battle_state.turn_state
	)


func _build_ability_availability_results(
	unit: UnitRuntime
) -> Array[AbilityAvailabilityResult]:
	var results: Array[AbilityAvailabilityResult] = []

	if unit == null:
		return results

	for ability_runtime in unit.active_abilities:
		results.append(
			ability_availability_service.evaluate(
				battle_state,
				ability_runtime
			)
		)

	return results
	
# ============================================================
# ПРАВЫЙ КЛИК И КЛАВИАТУРА
# ============================================================

func _unhandled_input(event: InputEvent) -> void:
	if not _is_initialized:
		return

	if event is InputEventMouseButton:
		if (
			event.button_index == MOUSE_BUTTON_RIGHT
			and event.pressed
		):
			_cancel_pending_ability()
			get_viewport().set_input_as_handled()
			return

	if event is InputEventKey:
		if event.pressed and not event.echo:
			if (
				event.keycode == KEY_ENTER
				or event.keycode == KEY_KP_ENTER
			):
				request_end_turn()
				get_viewport().set_input_as_handled()
				return


func _cancel_pending_ability() -> void:
	if battle_state == null:
		return

	if battle_state.pending_decision != null:
		print("Pending reaction target cannot be cancelled")
		return

	if battle_state.pending_ability == null:
		return

	print("Ability selection cancelled")

	battle_state.clear_pending_ability()

	if battlefield_view != null:
		battlefield_view.set_targeting(
			false,
			null
		)

	_refresh_views()


# ============================================================
# ЗАВЕРШЕНИЕ КЛИКА СПОСОБНОСТИ
# ============================================================

func _finish_ability_click(
	execution_result: AbilityExecutionResult
) -> void:
	if battle_state == null:
		return

	battle_state.clear_pending_ability()

	if battle_state.pending_decision != null:
		_sync_pending_decision_targeting()
	else:
		if battlefield_view != null:
			battlefield_view.set_targeting(
				false,
				null
			)

	if (
		execution_result != null
		and execution_result.was_committed()
		and battle_state.pending_decision == null
	):
		battle_state.check_victory_condition()

	_refresh_views()


# ============================================================
# ЗАВЕРШЕНИЕ АКТИВАЦИИ
# ============================================================

func _end_current_activation() -> void:
	if battle_state == null:
		return

	if battle_state.is_battle_over:
		print(
			"BattleEngine: battle is over, "
			+ "cannot end activation"
		)
		return

	if battle_state.pending_ability != null:
		battle_state.clear_pending_ability()

	if battlefield_view != null:
		battlefield_view.set_targeting(
			false,
			null
		)

	command_dispatcher.dispatch_command({
		"type": "end_turn"
	})

	if battle_state.pending_decision != null:
		_sync_pending_decision_targeting()

	_refresh_views()


# ============================================================
# ВЫБОР СПОСОБНОСТИ
# ============================================================

func _on_ability_selected(
	ability_runtime: UnitAbilityRuntime
) -> void:
	if battle_state == null:
		push_error("BattleEngine: battle_state is null")
		return

	if battle_state.is_battle_over:
		print(
			"BattleEngine: battle is over, "
			+ "ability selection ignored"
		)
		return

	if ability_runtime == null or ability_runtime.data == null:
		push_error(
			"BattleEngine: selected ability is null"
		)
		return

	if battle_state.active_unit == null:
		push_error(
			"BattleEngine: active_unit is null"
		)
		return

	var availability := ability_availability_service.evaluate(
		battle_state,
		ability_runtime
	)

	if not availability.is_available:
		print(
			"BattleEngine: ability is unavailable: ",
			availability.get_summary()
		)
		return

	var schema_result := ability_algorithm_registry.validate_unit_ability(
		ability_runtime.data
	)

	if not schema_result.is_valid:
		push_error(
			"BattleEngine: invalid ability schema:\n"
			+ schema_result.get_summary()
		)
		return

	var valid_target_cells := targeting_service.get_valid_selection_cells(
		battle_state,
		battle_state.active_unit,
		ability_runtime.data,
		schema_result.resolved_parameters
	)

	if valid_target_cells.is_empty():
		print(
			"BattleEngine: ability has no valid targets: ",
			ability_runtime.data.ability_name
		)
		return

	battle_state.set_pending_ability(
		ability_runtime
	)

	battlefield_view.set_targeting(
		true,
		battle_state.active_unit,
		valid_target_cells
	)

	battlefield_view.draw_battlefield(
		battle_state
	)

	print("")
	print(
		"Ability selected: ",
		ability_runtime.data.ability_name
	)
	print("Choose target on battlefield")


# ============================================================
# КЛИК ПО КЛЕТКЕ
# ============================================================

func _on_cell_clicked(cell: CellRuntime) -> void:
	if cell == null:
		return

	if battle_state == null:
		push_error("BattleEngine: battle_state is null")
		return

	if battle_state.is_battle_over:
		print(
			"BattleEngine: battle is over, input ignored"
		)
		return

	if battle_state.pending_decision != null:
		_handle_pending_decision_click(
			cell,
			battle_state.get_unit_on_cell(cell)
		)
		return

	if battle_state.active_unit == null:
		push_error(
			"BattleEngine: active_unit is null"
		)
		return

	var target_unit: UnitRuntime = (
		battle_state.get_unit_on_cell(cell)
	)

	if battle_state.pending_ability == null:
		_handle_movement_click(
			cell,
			target_unit
		)
		return

	_handle_ability_click(
		cell,
		target_unit
	)


# ============================================================
# ВЫБОР ЦЕЛИ ДЛЯ ПРИОСТАНОВЛЕННОЙ РЕАКЦИИ
# ============================================================

func _handle_pending_decision_click(
	cell : CellRuntime,
	target_unit : UnitRuntime
) -> void:
	var decision := battle_state.pending_decision

	if decision == null:
		return

	if target_unit == null or not decision.has_option(target_unit):
		print(
			"BattleEngine: cell is not a pending decision option: ",
			cell.x,
			",",
			cell.y
		)
		return

	var command_result : Variant = command_dispatcher.dispatch_command({
		"type": "select_decision_target",
		"decision_id": decision.decision_id,
		"target_unit": target_unit
	})
	var resolution := command_result as DecisionResolutionResult

	if resolution == null or not resolution.was_resolved():
		var failure_message := "Решение не было принято."

		if resolution != null:
			failure_message = resolution.message

		print("BattleEngine: ", failure_message)
		_sync_pending_decision_targeting()
		_refresh_views()
		return

	if battle_state.pending_decision != null:
		_sync_pending_decision_targeting()
	elif battlefield_view != null:
		battlefield_view.set_targeting(false, null)

	if battle_state.pending_decision == null:
		battle_state.check_victory_condition()

	_refresh_views()


func _sync_pending_decision_targeting() -> void:
	if battlefield_view == null or battle_state == null:
		return

	var decision := battle_state.pending_decision

	if decision == null:
		battlefield_view.set_targeting(false, null)
		return

	battlefield_view.set_targeting(
		true,
		decision.source_unit,
		decision.get_option_cells()
	)

	print(decision.reason)


# ============================================================
# КЛИК В РЕЖИМЕ ДВИЖЕНИЯ
# ============================================================

func _handle_movement_click(
	cell: CellRuntime,
	target_unit: UnitRuntime
) -> void:
	if target_unit != null:
		print(
			"Cannot move to occupied cell: ",
			cell.x,
			",",
			cell.y
		)
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

func _handle_ability_click(
	cell: CellRuntime,
	target_unit: UnitRuntime
) -> void:
	var pending_ability: UnitAbilityRuntime = (
		battle_state.pending_ability
	)

	if pending_ability == null:
		push_error(
			"BattleEngine: pending_ability is null"
		)
		return

	if (
		pending_ability.data == null
		or pending_ability.data.ability == null
	):
		push_error(
			"BattleEngine: pending_ability "
			+ "has no AbilityData"
		)
		return

	var target_rule_id: String = (
		pending_ability.data.ability.target_rule_id
	)

	_print_ability_click_debug(
		cell,
		target_unit,
		pending_ability,
		target_rule_id
	)

	if target_rule_id in [
		TARGET_RULE_AREA_AROUND_CELL,
		TARGET_RULE_SINGLE_EMPTY_DEPLOYMENT_CELL
	]:
		var area_result := _dispatch_use_ability(
			cell,
			target_unit,
			pending_ability
		)

		_finish_ability_click(area_result)
		return

	if target_unit == null:
		print(
			"Clicked empty cell while ability "
			+ "requires unit target: ",
			cell.x,
			",",
			cell.y
		)
		return

	var execution_result := _dispatch_use_ability(
		cell,
		target_unit,
		pending_ability
	)

	_finish_ability_click(execution_result)


func _dispatch_use_ability(
	cell: CellRuntime,
	target_unit: UnitRuntime,
	pending_ability: UnitAbilityRuntime
) -> AbilityExecutionResult:
	var command_result : Variant = command_dispatcher.dispatch_command({
		"type": "use_ability",
		"source_unit": battle_state.active_unit,
		"target_unit": target_unit,
		"target_cell": cell,
		"ability_runtime": pending_ability
	})

	var execution_result := command_result as AbilityExecutionResult

	if execution_result == null:
		push_error(
			"BattleEngine: ability command returned no typed result"
		)
		execution_result = AbilityExecutionResult.rejected(
			AbilityExecutionResult.Status.FAILED_EXECUTION,
			"Команда способности не вернула результат."
		)

	return execution_result


func _print_ability_click_debug(
	cell: CellRuntime,
	target_unit: UnitRuntime,
	pending_ability: UnitAbilityRuntime,
	target_rule_id: String
) -> void:
	var target_name: String = "none"

	if target_unit != null:
		target_name = target_unit.data.unit_name

	print(
		"BattleEngine ability click | ability: ",
		pending_ability.data.ability_name,
		" | target_rule_id: ",
		target_rule_id,
		" | cell: ",
		cell.x,
		",",
		cell.y,
		" | target_unit: ",
		target_name
	)
