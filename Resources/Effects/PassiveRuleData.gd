extends Resource

class_name PassiveRuleData


enum RuleType {
	BLOCK_HEALING_KIND,
	MODIFY_INITIATIVE,
	MODIFY_MOVEMENT,
	PREVENT_DEATH
}


@export var rule_type : RuleType = RuleType.BLOCK_HEALING_KIND

@export var healing_kind : Impact.HealingKind = (
	Impact.HealingKind.REGENERATION
)

# Аддитивная величина для MODIFY_INITIATIVE и MODIFY_MOVEMENT.
@export_range(-99, 99, 1) var modifier_amount : int = 0

# PREVENT_DEATH возвращает носителя из DEATH_PENDING в ALIVE с этим HP,
# после чего весь создавший правило EffectRuntime расходуется.
@export_range(1, 999, 1) var restored_hp : int = 1
