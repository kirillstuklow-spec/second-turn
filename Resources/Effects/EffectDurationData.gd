extends Resource

class_name EffectDurationData


enum DurationUnit {
	PERMANENT,
	CARRIER_ACTIVATIONS,
	ROUNDS
}


@export var duration_unit : DurationUnit = DurationUnit.PERMANENT

@export_range(0, 99, 1) var amount : int = 0

# Если эффект наложен или обновлён во время активации носителя,
# окончание этой же активации не уменьшает длительность.
@export var skip_application_activation : bool = true
