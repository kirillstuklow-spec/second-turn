extends RefCounted

class_name EffectRuntime

# Паспорт эффекта
var data : EffectData

# Кто создал эффект
var source = null

# На ком или на чем находится эффект
var carrier = null

# Оставшаяся длительность
var remaining_duration : int
