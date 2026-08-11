extends RefCounted

class_name CombatEvent


enum Kind {
	DAMAGE_APPLIED,
	HEALING_APPLIED,
	EFFECT_APPLIED,
	EFFECT_REFRESHED,
	ACTIVATION_ENDED,
	DEATH_CONFIRMED,
	UNIT_SUMMONED,
	DEATH_PREVENTED,
	UNIT_MOVED,
	# Добавлен в конец, чтобы не сдвигать уже сериализованные enum-значения
	# событий в .tres-ресурсах.
	HEALTH_LOST,
	BATTLEFIELD_OBJECT_CREATED,
	BATTLEFIELD_OBJECT_REMOVED,
	# Публикуется только для применённого Impact в клетке, покрытой хотя бы
	# одним объектом. Это пространственный факт попадания, а не второй урон.
	IMPACT_APPLIED,
	# Добавлен в конец, чтобы не сдвигать значения существующих событий.
	BATTLEFIELD_OBJECT_TRIGGERED,
	# Факт разрешённого пространственного воздействия. В отличие от
	# IMPACT_APPLIED публикуется и после блокировки.
	IMPACT_RESOLVED
}


enum HealthLossCause {
	NONE,
	DAMAGE,
	NEGATIVE_HEALING,
	ABILITY_COST
}


var event_id : StringName = &""

var kind : Kind = Kind.DAMAGE_APPLIED

var execution_id : StringName = &""

var root_execution_id : StringName = &""

var impact_id : StringName = &""

var cause_event_id : StringName = &""

var source_unit : UnitRuntime = null

var source_object : Variant = null

var source_ability_data : UnitAbilityData = null

var target_unit : UnitRuntime = null

var battlefield_object : BattlefieldObjectRuntime = null

var battlefield_object_runtime_id : StringName = &""

var battlefield_object_id : StringName = &""

var battlefield_object_trigger_id : StringName = &""

var object_removal_reason : StringName = &""

var source_cell : CellRuntime = null

var source_cell_x : int = -1

var source_cell_y : int = -1

var target_cell : CellRuntime = null

var target_cell_x : int = -1

var target_cell_y : int = -1

var applied_amount : int = 0

# Знак изменения HP хранится отдельно от applied_amount. Последний всегда
# является положительной эффективностью, а hp_delta различает лечение (+)
# и отрицательное HEALING (-) без превращения его в DAMAGE_APPLIED.
var hp_delta : int = 0

var impact_outcome : StringName = &""

# HEALTH_LOST объединяет реакции на сам факт уменьшения HP, но сохраняет
# исходную природу потери для правил, которым важно различать урон, лечение
# отрицательной величиной и стоимость способности.
var health_loss_cause : HealthLossCause = HealthLossCause.NONE

var source_type : StringName = &""

var interaction_type : Impact.InteractionType = Impact.InteractionType.MELEE

var origin_effect_runtime_id : StringName = &""

var applied_effect_runtime_id : StringName = &""

var effect_id : StringName = &""

var reaction_depth : int = 0

# Время фиксируется в самом событии, чтобы поставленная реакция не зависела
# от более позднего изменения TurnState.
var activation_serial : int = -1

var round_number : int = 0
