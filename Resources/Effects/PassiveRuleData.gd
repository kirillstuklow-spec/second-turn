extends Resource

class_name PassiveRuleData


enum RuleType {
	BLOCK_HEALING_KIND
}


@export var rule_type : RuleType = RuleType.BLOCK_HEALING_KIND

@export var healing_kind : Impact.HealingKind = (
	Impact.HealingKind.REGENERATION
)
