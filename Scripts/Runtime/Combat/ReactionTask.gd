extends RefCounted

class_name ReactionTask


var reaction_id : StringName = &""

var execution_id : StringName = &""

var root_execution_id : StringName = &""

var reaction_depth : int = 0

var trigger_event : CombatEvent = null

var trigger_data : EffectTriggerData = null

var ability_trigger_data : AbilityTriggerData = null

var response_plan_data : ImpactPlanData = null

var source_effect_runtime : EffectRuntime = null

var source_effect_runtime_id : StringName = &""

var source_effect_data : EffectData = null

var source_ability_runtime : UnitAbilityRuntime = null

# Эти ссылки копируются в момент постановки реакции в очередь.
# Обновление того же EffectRuntime не меняет уже поставленную задачу.
var source_unit : UnitRuntime = null

var source_ability_data : UnitAbilityData = null

var carrier : UnitRuntime = null

# Заполняется для реакции с выбором игрока. До выбора цель отсутствует, а
# после выбора тот же ReactionTask продолжает исходную цепочку.
var selected_target : UnitRuntime = null

var target_origin_cell : CellRuntime = null
