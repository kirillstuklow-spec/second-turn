extends Resource

class_name EffectTriggerData


enum CarrierRelation {
	ANY,
	CARRIER_IS_EVENT_TARGET,
	CARRIER_IS_EVENT_SOURCE
}


enum FrequencyPolicy {
	EACH_MATCHING_EVENT,
	ONCE_PER_ACTIVATION,
	ONCE_PER_ROUND,
	ONCE_TOTAL
}


@export var trigger_id : String = ""

@export var event_kind : CombatEvent.Kind = CombatEvent.Kind.DAMAGE_APPLIED

@export var carrier_relation : CarrierRelation = (
	CarrierRelation.CARRIER_IS_EVENT_TARGET
)

@export_range(0, 999, 1) var minimum_applied_amount : int = 1

@export var ignore_same_effect_runtime : bool = true

# Не позволяет эффекту реагировать в той же активации, в которой он был
# наложен или обновлён. Это отдельное правило триггера: длительность при этом
# по-прежнему управляется EffectDurationData.
@export var skip_application_activation : bool = false

@export var frequency_policy : FrequencyPolicy = (
	FrequencyPolicy.EACH_MATCHING_EVENT
)

@export var response_plan_data : ImpactPlanData = null
