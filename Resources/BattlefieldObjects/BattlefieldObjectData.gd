extends Resource

class_name BattlefieldObjectData


@export var object_id : String = ""

@export var object_name : String = ""

@export_multiline var description : String = ""

# Смещения считаются от выбранной клетки-якоря. Для первого прототипа объект
# можно разместить только там, где все перечисленные клетки существуют.
@export var coverage_offsets : Array[Vector2i] = [Vector2i.ZERO]

# Ноль означает постоянный объект. Положительное число — количество полных
# последующих раундов; неполный раунд создания длительность не уменьшает.
@export_range(0, 99, 1) var lifetime_rounds : int = 0

# Нерасходуемые защиты, которые объект предоставляет всем юнитам в покрытых
# клетках. Они существуют только в пространстве и не копируются в UnitRuntime.
@export var provided_defenses : Array[String] = []

@export var triggers : Array[BattlefieldObjectTriggerData] = []

@export var visual_data : BattlefieldObjectVisualData = null


func get_validation_issues() -> PackedStringArray:
	var issues := PackedStringArray()
	var normalized_id := object_id.strip_edges()

	if normalized_id.is_empty():
		issues.append("object_id пуст.")
	elif normalized_id != object_id:
		issues.append("object_id содержит пробелы по краям.")

	if coverage_offsets.is_empty():
		issues.append("coverage_offsets не содержит клеток.")

	var seen_offsets : Dictionary = {}

	for offset in coverage_offsets:
		var key := "%d:%d" % [offset.x, offset.y]

		if seen_offsets.has(key):
			issues.append("coverage_offsets содержит повтор %s." % key)
		else:
			seen_offsets[key] = true

	if not seen_offsets.has("0:0"):
		issues.append("coverage_offsets должен включать клетку-якорь 0:0.")

	var seen_defenses : Dictionary = {}

	for defense_index in range(provided_defenses.size()):
		var defense := provided_defenses[defense_index]
		var normalized_defense := defense.strip_edges()
		var defense_prefix := "provided_defenses[%d]" % defense_index

		if normalized_defense.is_empty():
			issues.append(defense_prefix + ": защита пуста.")
		elif normalized_defense != defense:
			issues.append(defense_prefix + ": защита содержит пробелы по краям.")
		elif seen_defenses.has(normalized_defense):
			issues.append(defense_prefix + ": защита повторяется.")
		else:
			seen_defenses[normalized_defense] = true

	var seen_trigger_ids : Dictionary = {}

	for trigger_index in range(triggers.size()):
		var trigger := triggers[trigger_index]
		var prefix := "triggers[%d]" % trigger_index

		if trigger == null:
			issues.append(prefix + ": триггер отсутствует.")
			continue

		var trigger_id := trigger.trigger_id.strip_edges()

		if trigger_id.is_empty():
			issues.append(prefix + ": trigger_id пуст.")
		elif trigger_id != trigger.trigger_id:
			issues.append(prefix + ": trigger_id содержит пробелы по краям.")
		elif seen_trigger_ids.has(trigger_id):
			issues.append(prefix + ": trigger_id повторяется.")
		else:
			seen_trigger_ids[trigger_id] = true

		if trigger.event_kind not in CombatEvent.Kind.values():
			issues.append(prefix + ": неизвестный event_kind.")

		if (
			trigger.target_policy
			not in BattlefieldObjectTriggerData.TargetPolicy.values()
		):
			issues.append(prefix + ": неизвестная target_policy.")

		if (
			trigger.event_location_policy
			not in BattlefieldObjectTriggerData.EventLocationPolicy.values()
		):
			issues.append(prefix + ": неизвестная event_location_policy.")

		if (
			trigger.response_plan_data == null
			and not trigger.consume_object_on_trigger
		):
			issues.append(prefix + ": response_plan_data отсутствует.")

	return issues
