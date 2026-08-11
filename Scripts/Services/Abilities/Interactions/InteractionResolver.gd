extends RefCounted

class_name InteractionResolver


const RNG_PURPOSE_ARMOR_BLOCK : StringName = &"armor_block"

const MIN_ARMOR : int = 0
const MAX_ARMOR : int = 5

const MIN_ARMOR_PENETRATION : int = -5
const MAX_ARMOR_PENETRATION : int = 5


func resolve(
	impact : Impact,
	target_snapshot : UnitStateSnapshot,
	battle_snapshot : BattleStateSnapshot,
	battle_rng : BattleRng
) -> InteractionResolution:
	var resolution := InteractionResolution.create(impact)
	var input_error := _get_input_error(
		impact,
		target_snapshot,
		battle_snapshot
	)

	if not input_error.is_empty():
		resolution.outcome = InteractionResolution.Outcome.INVALID
		resolution.message = input_error
		return resolution

	resolution.interaction_type_tag = (
		Impact.get_interaction_type_id(impact.interaction_type)
	)
	resolution.source_type_tag = impact.source_type

	# Иерархия фиксирована: сначала все иммунитеты, затем все защиты.
	# Внутри одного уровня механический тип всегда важнее источника.
	if target_snapshot.has_immunity(
		resolution.interaction_type_tag
	):
		return _block(
			resolution,
			InteractionResolution.Outcome.BLOCKED_IMMUNITY,
			InteractionResolution.Stage.IMMUNITY_INTERACTION_TYPE,
			resolution.interaction_type_tag
		)

	if (
		resolution.source_type_tag != &""
		and target_snapshot.has_immunity(
			resolution.source_type_tag
		)
	):
		return _block(
			resolution,
			InteractionResolution.Outcome.BLOCKED_IMMUNITY,
			InteractionResolution.Stage.IMMUNITY_SOURCE_TYPE,
			resolution.source_type_tag
		)

	if target_snapshot.has_defense(
		resolution.interaction_type_tag
	):
		return _block(
			resolution,
			InteractionResolution.Outcome.BLOCKED_DEFENSE,
			InteractionResolution.Stage.DEFENSE_INTERACTION_TYPE,
			resolution.interaction_type_tag
		)

	if (
		resolution.source_type_tag != &""
		and target_snapshot.has_defense(
			resolution.source_type_tag
		)
	):
		return _block(
			resolution,
			InteractionResolution.Outcome.BLOCKED_DEFENSE,
			InteractionResolution.Stage.DEFENSE_SOURCE_TYPE,
			resolution.source_type_tag
		)

	if not _uses_armor(impact.interaction_type):
		return resolution

	if battle_rng == null:
		resolution.outcome = InteractionResolution.Outcome.INVALID
		resolution.message = "InteractionResolver: BattleRng is unavailable"
		return resolution

	resolution.stage = InteractionResolution.Stage.ARMOR
	resolution.armor_was_checked = true
	resolution.effective_armor = clamp(
		target_snapshot.armor - impact.armor_penetration,
		MIN_ARMOR,
		MAX_ARMOR
	)
	resolution.block_chance = resolution.effective_armor * 20

	if resolution.block_chance <= 0:
		return resolution

	resolution.armor_roll = battle_rng.roll_int(
		RNG_PURPOSE_ARMOR_BLOCK,
		1,
		100,
		{
			"execution_id": impact.execution_id,
			"impact_id": impact.impact_id,
			"target_name": target_snapshot.unit_name,
			"target_team_id": target_snapshot.team_id,
			"round_number": battle_snapshot.round_number,
			"interaction_type": resolution.interaction_type_tag,
			"source_type": resolution.source_type_tag,
			"armor": target_snapshot.armor,
			"armor_penetration": impact.armor_penetration,
			"effective_armor": resolution.effective_armor
		}
	)

	if resolution.armor_roll == null:
		resolution.outcome = InteractionResolution.Outcome.INVALID
		resolution.message = "InteractionResolver: armor roll failed"
		return resolution

	if resolution.armor_roll.value <= resolution.block_chance:
		return _block(
			resolution,
			InteractionResolution.Outcome.BLOCKED_ARMOR,
			InteractionResolution.Stage.ARMOR,
			&"armor"
		)

	return resolution


func _get_input_error(
	impact : Impact,
	target_snapshot : UnitStateSnapshot,
	battle_snapshot : BattleStateSnapshot
) -> String:
	if impact == null:
		return "InteractionResolver: impact is null"

	if target_snapshot == null:
		return "InteractionResolver: target snapshot is null"

	if not target_snapshot.is_alive:
		return "InteractionResolver: target is not alive"

	if battle_snapshot == null:
		return "InteractionResolver: battle snapshot is null"

	if impact.interaction_type not in [
		Impact.InteractionType.MELEE,
		Impact.InteractionType.RANGED,
		Impact.InteractionType.MAGIC,
		Impact.InteractionType.HEALING,
		Impact.InteractionType.SUMMON,
		Impact.InteractionType.EFFECT,
		Impact.InteractionType.MOVEMENT,
		Impact.InteractionType.OBJECT,
		Impact.InteractionType.CELL
	]:
		return "InteractionResolver: interaction type is invalid"

	if (
		impact.armor_penetration < MIN_ARMOR_PENETRATION
		or impact.armor_penetration > MAX_ARMOR_PENETRATION
	):
		return (
			"InteractionResolver: armor penetration must be between "
			+ "%d and %d"
			% [MIN_ARMOR_PENETRATION, MAX_ARMOR_PENETRATION]
		)

	return ""


func _uses_armor(
	interaction_type : Impact.InteractionType
) -> bool:
	return interaction_type in [
		Impact.InteractionType.MELEE,
		Impact.InteractionType.RANGED,
		Impact.InteractionType.MAGIC
	]


func _block(
	resolution : InteractionResolution,
	outcome : InteractionResolution.Outcome,
	stage : InteractionResolution.Stage,
	matched_tag : StringName
) -> InteractionResolution:
	resolution.outcome = outcome
	resolution.stage = stage
	resolution.matched_tag = matched_tag

	if outcome == InteractionResolution.Outcome.BLOCKED_DEFENSE:
		resolution.defense_to_consume = matched_tag

	return resolution
