extends Resource

class_name EffectData


enum ReapplyPolicy {
	REFRESH,
	IGNORE,
	REPLACE
}


@export var effect_id : String = ""

@export var effect_name : String = ""

@export_multiline var description : String = ""

@export var reapply_policy : ReapplyPolicy = ReapplyPolicy.REFRESH

@export var duration : EffectDurationData = null

@export var triggers : Array[EffectTriggerData] = []

@export var passive_rules : Array[PassiveRuleData] = []
