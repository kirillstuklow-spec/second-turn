extends Resource

class_name BiomeVisualData


# ============================================================
# ИДЕНТИФИКАЦИЯ
# ============================================================

@export var biome_id: String = ""

@export var biome_name: String = ""

@export_multiline var description: String = ""


# ============================================================
# ВИЗУАЛЬНЫЙ ПУЛ БИОМА
# ============================================================

@export var default_cell_visual: CellVisualData = null

@export var available_cell_visuals: Array[CellVisualData] = []
