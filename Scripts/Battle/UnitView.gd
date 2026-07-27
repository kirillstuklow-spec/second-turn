extends Node2D

class_name UnitView


# ============================================================
# СОСТАВ ПРЕДСТАВЛЕНИЯ
# ============================================================

@onready var visual_root: Node2D = %VisualRoot
@onready var static_sprite: Sprite2D = %StaticSprite
@onready var animated_sprite: AnimatedSprite2D = %AnimatedSprite
@onready var fallback_panel: Polygon2D = %FallbackPanel
@onready var fallback_label: Label = %FallbackLabel
@onready var status_label: Label = %StatusLabel


# ============================================================
# ТЕКУЩИЕ ДАННЫЕ
# ============================================================

var displayed_unit: UnitRuntime = null
var displayed_data: UnitData = null
var cell_size: Vector2 = Vector2(80, 80)

var _has_battlefield_position: bool = false
var _movement_tween: Tween = null


# ============================================================
# ОТОБРАЖЕНИЕ RUNTIME-ЮНИТА
# ============================================================

func show_runtime(
	unit: UnitRuntime,
	new_cell_size: Vector2,
	animate_movement: bool = true
) -> void:
	if unit == null or unit.data == null:
		hide()
		return

	if not unit.is_alive or unit.cell == null:
		hide()
		return

	displayed_unit = unit
	displayed_data = unit.data
	cell_size = new_cell_size

	_apply_data_visuals(displayed_data)
	_update_runtime_status()
	_move_to_runtime_cell(animate_movement)
	show()


# ============================================================
# ПРЕДПРОСМОТР DATA-РЕСУРСА
# ============================================================

func show_preview(
	unit_data: UnitData,
	preview_cell_size: Vector2 = Vector2(80, 80)
) -> void:
	displayed_unit = null
	displayed_data = unit_data
	cell_size = preview_cell_size
	_has_battlefield_position = false

	position = Vector2.ZERO

	if unit_data == null:
		hide()
		return

	_apply_data_visuals(unit_data)
	status_label.text = unit_data.unit_name
	show()


# ============================================================
# ПЕРЕМЕЩЕНИЕ ПРЕДСТАВЛЕНИЯ
# ============================================================

func _move_to_runtime_cell(animate_movement: bool) -> void:
	if displayed_unit == null or displayed_unit.cell == null:
		return

	var target_position := Vector2(
		displayed_unit.cell.x * cell_size.x + cell_size.x * 0.5,
		displayed_unit.cell.y * cell_size.y + cell_size.y * 0.5
	)

	if _movement_tween != null and _movement_tween.is_valid():
		_movement_tween.kill()

	if not _has_battlefield_position or not animate_movement:
		position = target_position
		_has_battlefield_position = true
		return

	if position.is_equal_approx(target_position):
		return

	_movement_tween = create_tween()
	_movement_tween.set_trans(Tween.TRANS_QUAD)
	_movement_tween.set_ease(Tween.EASE_OUT)
	_movement_tween.tween_property(
		self,
		"position",
		target_position,
		0.16
	)


# ============================================================
# ВИЗУАЛЬНЫЕ ДАННЫЕ
# ============================================================

func _apply_data_visuals(unit_data: UnitData) -> void:
	_reset_visual_nodes()

	var visual_data: UnitVisualData = unit_data.visual_data

	if visual_data == null:
		_show_fallback(unit_data)
		return

	visual_root.position = visual_data.cell_offset

	if _has_playable_animation(visual_data.idle_frames):
		_show_animation(
			visual_data.idle_frames,
			visual_data.visual_scale
		)
		return

	if visual_data.battlefield_texture != null:
		_show_texture(
			visual_data.battlefield_texture,
			visual_data.visual_scale
		)
		return

	_show_fallback(unit_data)


func _reset_visual_nodes() -> void:
	static_sprite.hide()
	animated_sprite.hide()
	fallback_panel.hide()
	fallback_label.hide()

	animated_sprite.stop()
	animated_sprite.sprite_frames = null
	static_sprite.texture = null

	visual_root.position = Vector2.ZERO
	visual_root.scale = Vector2.ONE


func _show_animation(
	frames: SpriteFrames,
	scale_multiplier: Vector2
) -> void:
	var reference_texture := frames.get_frame_texture(
		UnitVisualData.REQUIRED_ANIMATION_NAME,
		0
	)

	visual_root.scale = (
		_calculate_fit_scale(reference_texture)
		* scale_multiplier
	)

	animated_sprite.sprite_frames = frames
	animated_sprite.animation = UnitVisualData.REQUIRED_ANIMATION_NAME
	animated_sprite.show()
	animated_sprite.play()


func _show_texture(
	texture: Texture2D,
	scale_multiplier: Vector2
) -> void:
	visual_root.scale = (
		_calculate_fit_scale(texture)
		* scale_multiplier
	)

	static_sprite.texture = texture
	static_sprite.show()


func _show_fallback(unit_data: UnitData) -> void:
	visual_root.scale = Vector2.ONE
	fallback_panel.show()
	fallback_label.text = _get_fallback_text(unit_data.unit_name)
	fallback_label.show()


func _calculate_fit_scale(texture: Texture2D) -> Vector2:
	if texture == null:
		return Vector2.ONE

	var texture_size := texture.get_size()

	if texture_size.x <= 0.0 or texture_size.y <= 0.0:
		return Vector2.ONE

	var available_size: float = (
		minf(cell_size.x, cell_size.y) * 0.72
	)
	var fit_factor: float = minf(
		available_size / texture_size.x,
		available_size / texture_size.y
	)

	return Vector2(fit_factor, fit_factor)


func _has_playable_animation(frames: SpriteFrames) -> bool:
	if frames == null:
		return false

	if not frames.has_animation(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	):
		return false

	return frames.get_frame_count(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	) > 0


# ============================================================
# СМЕРТЬ
# ============================================================

func play_death_and_remove() -> void:
	if displayed_data == null or displayed_data.visual_data == null:
		queue_free()
		return

	var death_frames := displayed_data.visual_data.death_frames

	if not _has_playable_animation(death_frames):
		queue_free()
		return

	_reset_visual_nodes()
	_show_animation(
		death_frames,
		displayed_data.visual_data.visual_scale
	)

	var frame_count := death_frames.get_frame_count(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	)
	var animation_speed := death_frames.get_animation_speed(
		UnitVisualData.REQUIRED_ANIMATION_NAME
	)
	var duration := 0.35

	if animation_speed > 0.0:
		duration = max(
			float(frame_count) / animation_speed,
			0.1
		)

	var death_tween := create_tween()
	death_tween.tween_interval(duration)
	death_tween.tween_callback(queue_free)


# ============================================================
# ПОДПИСИ
# ============================================================

func _update_runtime_status() -> void:
	if displayed_unit == null or displayed_data == null:
		status_label.text = ""
		return

	status_label.text = "%s\nHP: %d" % [
		displayed_data.unit_name,
		displayed_unit.current_hp
	]


func _get_fallback_text(unit_name: String) -> String:
	var trimmed_name := unit_name.strip_edges()

	if trimmed_name.is_empty():
		return "?"

	return trimmed_name.left(2).to_upper()
