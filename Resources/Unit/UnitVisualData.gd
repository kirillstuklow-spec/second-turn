extends Resource

class_name UnitVisualData


# ============================================================
# ВИЗУАЛЬНЫЙ СТАНДАРТ
# ============================================================

const REQUIRED_FRAME_SIZE : Vector2i = Vector2i(128, 128)

const REQUIRED_ANIMATION_NAME : StringName = &"default"


# ============================================================
# ПОРТРЕТ
# ============================================================

@export var portrait : Texture2D


# ============================================================
# БАЗОВЫЕ АНИМАЦИИ
# ============================================================

@export var idle_frames : SpriteFrames

@export var move_frames : SpriteFrames

@export var block_frames : SpriteFrames

@export var hit_frames : SpriteFrames

@export var death_frames : SpriteFrames


# ============================================================
# РАЗМЕЩЕНИЕ НА ПОЛЕ
# ============================================================

@export var visual_scale : Vector2 = Vector2.ONE

@export var cell_offset : Vector2 = Vector2.ZERO
