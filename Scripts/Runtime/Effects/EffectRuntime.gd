extends RefCounted

class_name EffectRuntime


var runtime_id : StringName = &""

# Паспорт эффекта
var data : EffectData

# Кто создал эффект
var source = null

var source_unit : UnitRuntime = null

var source_ability_data : UnitAbilityData = null

# На ком или на чем находится эффект
var carrier = null

# Оставшаяся длительность
var remaining_duration : int = -1

# Серийный номер активации, во время которой эффект был в последний раз
# наложен или обновлён. Нужен, чтобы не списывать неполную активацию.
var last_application_activation_serial : int = -1

# Номер раунда последнего наложения или обновления. Он позволяет эффектам,
# измеряемым раундами, не терять длительность в конце неполного раунда.
var last_application_round : int = -1

# Идемпотентность и настраиваемые частотные политики триггеров.
var processed_event_ids : Dictionary = {}

var trigger_last_activation_serial : Dictionary = {}

var trigger_last_round : Dictionary = {}

var triggered_once : Dictionary = {}


func setup(
	new_runtime_id : StringName,
	new_data : EffectData,
	new_source_unit : UnitRuntime,
	new_source_ability_data : UnitAbilityData,
	new_carrier : Variant,
	activation_serial : int,
	round_number : int
) -> void:
	runtime_id = new_runtime_id
	data = new_data
	source = new_source_unit
	source_unit = new_source_unit
	source_ability_data = new_source_ability_data
	carrier = new_carrier
	last_application_activation_serial = activation_serial
	last_application_round = round_number
	remaining_duration = _get_initial_duration()


func refresh_source_and_duration(
	new_source_unit : UnitRuntime,
	new_source_ability_data : UnitAbilityData,
	activation_serial : int,
	round_number : int
) -> void:
	source = new_source_unit
	source_unit = new_source_unit
	source_ability_data = new_source_ability_data
	last_application_activation_serial = activation_serial
	last_application_round = round_number
	remaining_duration = _get_initial_duration()


func get_effect_id() -> StringName:
	if data == null:
		return &""

	return StringName(data.effect_id)


func has_processed_event(
	trigger_id : StringName,
	event_id : StringName
) -> bool:
	if trigger_id == &"" or event_id == &"":
		return false

	return processed_event_ids.has(
		_get_trigger_event_key(trigger_id, event_id)
	)


func mark_event_processed(
	trigger_id : StringName,
	event_id : StringName,
	activation_serial : int,
	round_number : int
) -> void:
	if trigger_id != &"" and event_id != &"":
		processed_event_ids[
			_get_trigger_event_key(trigger_id, event_id)
		] = true

	trigger_last_activation_serial[trigger_id] = activation_serial
	trigger_last_round[trigger_id] = round_number
	triggered_once[trigger_id] = true


func _get_initial_duration() -> int:
	if data == null or data.duration == null:
		return -1

	if (
		data.duration.duration_unit
		== EffectDurationData.DurationUnit.PERMANENT
	):
		return -1

	return data.duration.amount


func _get_trigger_event_key(
	trigger_id : StringName,
	event_id : StringName
) -> String:
	return "%s:%s" % [trigger_id, event_id]
