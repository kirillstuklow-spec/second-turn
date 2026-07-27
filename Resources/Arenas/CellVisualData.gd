extends Resource

class_name CellVisualData


# ============================================================
# ИДЕНТИФИКАЦИЯ
# ============================================================

@export var cell_visual_id: String = ""

@export var display_name: String = ""

@export_multiline var description: String = ""


# ============================================================
# ОСНОВНОЙ ВИЗУАЛ
# ============================================================

@export var base_texture: Texture2D = null

@export var decoration_texture: Texture2D = null

@export var modulate: Color = Color.WHITE


# ============================================================
# ВАРИАЦИЯ ВНУТРИ КЛЕТКИ
# ============================================================

@export_range(0, 3, 1) var quarter_turns: int = 0

@export var flip_h: bool = false

@export var flip_v: bool = false
