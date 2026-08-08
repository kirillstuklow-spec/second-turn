extends Resource

class_name AbilityTriggerData


enum OwnerRelation {
	ANY,
	OWNER_IS_EVENT_TARGET,
	OWNER_IS_EVENT_SOURCE
}


enum EventSourceRelation {
	ANY,
	ENEMY,
	ALLY,
	SELF
}


enum InteractionFilter {
	ANY,
	MELEE,
	RANGED,
	MAGIC,
	HEALING,
	SUMMON,
	EFFECT
}


enum TargetSelectionPolicy {
	EVENT_SOURCE,
	PLAYER_CHOICE
}


@export var trigger_id : String = ""

@export var event_kind : CombatEvent.Kind = CombatEvent.Kind.DAMAGE_APPLIED

@export var owner_relation : OwnerRelation = (
	OwnerRelation.OWNER_IS_EVENT_TARGET
)

@export var event_source_relation : EventSourceRelation = (
	EventSourceRelation.ENEMY
)

@export var interaction_filter : InteractionFilter = (
	InteractionFilter.ANY
)

# EVENT_SOURCE сохраняет полностью автоматическое поведение вроде
# Контр-удара. PLAYER_CHOICE останавливает цепочку и создаёт PendingDecision,
# используя target_rule_id самой способности.
@export var target_selection_policy : TargetSelectionPolicy = (
	TargetSelectionPolicy.EVENT_SOURCE
)

@export var source_type_filter : String = ""

@export_range(0, 999, 1) var minimum_applied_amount : int = 1

# Реакция с false слушает только исходные воздействия глубины 0. Это
# позволяет контрудару оставаться обычной атакой, не создавая бесконечный
# обмен двумя одинаковыми реакциями.
@export var accept_reaction_events : bool = true

@export var require_owner_alive : bool = true

@export var require_event_source_alive : bool = true


func matches_interaction(
	interaction_type : Impact.InteractionType
) -> bool:
	match interaction_filter:
		InteractionFilter.ANY:
			return true

		InteractionFilter.MELEE:
			return interaction_type == Impact.InteractionType.MELEE

		InteractionFilter.RANGED:
			return interaction_type == Impact.InteractionType.RANGED

		InteractionFilter.MAGIC:
			return interaction_type == Impact.InteractionType.MAGIC

		InteractionFilter.HEALING:
			return interaction_type == Impact.InteractionType.HEALING

		InteractionFilter.SUMMON:
			return interaction_type == Impact.InteractionType.SUMMON

		InteractionFilter.EFFECT:
			return interaction_type == Impact.InteractionType.EFFECT

	return false
