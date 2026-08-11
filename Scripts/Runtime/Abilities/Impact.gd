extends RefCounted

class_name Impact


enum Operation {
	DAMAGE,
	HEAL,
	SUMMON,
	APPLY_EFFECT,
	MOVE,
	# Добавлено в конец, чтобы сохранить числовые значения уже
	# сериализованных операций в .tres.
	CREATE_OBJECT,
	# Пространственное воздействие на клетку без обязательной цели-юнита.
	# Используется, когда механике важен сам факт попадания в клетку.
	AFFECT_CELL
}


enum InteractionType {
	MELEE,
	RANGED,
	MAGIC,
	HEALING,
	SUMMON,
	EFFECT,
	MOVEMENT,
	# Размещение объекта не является ни призывом, ни воздействием на юнита.
	OBJECT,
	CELL
}


enum HealingKind {
	DIRECT,
	REGENERATION
}


var impact_id : StringName = &""

var execution_id : StringName = &""

var root_execution_id : StringName = &""

var parent_impact_id : StringName = &""

var order_index : int = -1

var source_object : Variant = null

var source_unit : UnitRuntime = null

var source_ability_data : UnitAbilityData = null

var target_unit : UnitRuntime = null

var target_cell : CellRuntime = null

var operation : Operation = Operation.DAMAGE

var interaction_type : InteractionType = InteractionType.MELEE

var source_type : StringName = &""

var magnitude : int = 0

var armor_penetration : int = 0

var healing_kind : HealingKind = HealingKind.DIRECT

var effect_data : EffectData = null

var summon_unit_data : UnitData = null

var battlefield_object_data : BattlefieldObjectData = null

# Максимальная манхэттенская дистанция для MOVE. Обычный и принудительный
# шаг используют 1; способность может передать собственную дальность.
var movement_max_distance : int = 1

var transition_condition : ImpactConditionData = null

var origin_effect_runtime_id : StringName = &""

var reaction_depth : int = 0

var metadata : Dictionary = {}


static func create(
	new_impact_id : StringName,
	new_execution_id : StringName,
	new_source_unit : UnitRuntime,
	new_target_unit : UnitRuntime,
	new_target_cell : CellRuntime,
	new_operation : Operation,
	new_interaction_type : InteractionType,
	new_source_type : StringName,
	new_magnitude : int,
	new_armor_penetration : int = 0
) -> Impact:
	var impact := Impact.new()
	impact.impact_id = new_impact_id
	impact.execution_id = new_execution_id
	impact.root_execution_id = new_execution_id
	impact.source_object = new_source_unit
	impact.source_unit = new_source_unit
	impact.target_unit = new_target_unit
	impact.target_cell = new_target_cell
	impact.operation = new_operation
	impact.interaction_type = new_interaction_type
	impact.source_type = new_source_type
	impact.magnitude = new_magnitude
	impact.armor_penetration = new_armor_penetration
	return impact


static func interaction_type_from_ability(
	ability_data : AbilityData
) -> InteractionType:
	if ability_data == null:
		return InteractionType.MELEE

	if ability_data.action_type == AbilityData.ActionType.HEAL:
		return InteractionType.HEALING

	if ability_data.action_type == AbilityData.ActionType.SUMMON:
		return InteractionType.SUMMON

	if ability_data.action_type == AbilityData.ActionType.MOVEMENT:
		return InteractionType.MOVEMENT

	match ability_data.targeting_form:
		AbilityData.TargetingForm.RANGED:
			return InteractionType.RANGED

		AbilityData.TargetingForm.MAGIC:
			return InteractionType.MAGIC

	return InteractionType.MELEE


static func get_interaction_type_id(
	value : InteractionType
) -> StringName:
	match value:
		InteractionType.MELEE:
			return &"melee"

		InteractionType.RANGED:
			return &"ranged"

		InteractionType.MAGIC:
			return &"magic"

		InteractionType.HEALING:
			return &"healing"

		InteractionType.SUMMON:
			return &"summon"

		InteractionType.EFFECT:
			return &"effect"

		InteractionType.MOVEMENT:
			return &"movement"

		InteractionType.OBJECT:
			return &"object"

		InteractionType.CELL:
			return &"cell"

	return &""


static func get_healing_kind_id(
	value : HealingKind
) -> StringName:
	match value:
		HealingKind.DIRECT:
			return &"direct"

		HealingKind.REGENERATION:
			return &"regeneration"

	return &""
