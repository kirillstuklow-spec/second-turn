extends Control

class_name ArenaGridCell


signal cell_interacted(
	grid_x: int,
	grid_y: int,
	mouse_button: int
)


const CELL_PREVIEW_SIZE := Vector2(72, 72)


var grid_x: int = 0
var grid_y: int = 0
var cell_visual: CellVisualData = null
var zone: int = ArenaZonePlacementData.Zone.NONE

var _background: ColorRect = null
var _base_texture: TextureRect = null
var _decoration_texture: TextureRect = null
var _zone_overlay: ColorRect = null
var _coordinate_label: Label = null
var _zone_label: Label = null
var _border: Panel = null


func _ready() -> void:
	custom_minimum_size = CELL_PREVIEW_SIZE
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	_build_layers()
	_refresh()


func setup(
	new_x: int,
	new_y: int
) -> void:
	grid_x = new_x
	grid_y = new_y

	if is_node_ready():
		_refresh()


func set_cell_visual(
	new_visual: CellVisualData
) -> void:
	cell_visual = new_visual

	if is_node_ready():
		_refresh()


func set_zone(
	new_zone: int
) -> void:
	zone = new_zone

	if is_node_ready():
		_refresh()


func _build_layers() -> void:
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_background.color = Color(0.12, 0.13, 0.16, 0.92)
	_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_background)

	_base_texture = _make_texture_layer()
	add_child(_base_texture)

	_decoration_texture = _make_texture_layer()
	add_child(_decoration_texture)

	_zone_overlay = ColorRect.new()
	_zone_overlay.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_zone_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zone_overlay)

	_coordinate_label = Label.new()
	_coordinate_label.position = Vector2(4, 2)
	_coordinate_label.size = Vector2(36, 20)
	_coordinate_label.add_theme_font_size_override("font_size", 11)
	_coordinate_label.add_theme_color_override(
		"font_shadow_color",
		Color.BLACK
	)
	_coordinate_label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)
	_coordinate_label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)
	_coordinate_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_coordinate_label)

	_zone_label = Label.new()
	_zone_label.position = Vector2(40, 49)
	_zone_label.size = Vector2(28, 19)
	_zone_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_zone_label.add_theme_font_size_override("font_size", 12)
	_zone_label.add_theme_color_override(
		"font_shadow_color",
		Color.BLACK
	)
	_zone_label.add_theme_constant_override(
		"shadow_offset_x",
		1
	)
	_zone_label.add_theme_constant_override(
		"shadow_offset_y",
		1
	)
	_zone_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_zone_label)

	_border = Panel.new()
	_border.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	_border.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var border_style := StyleBoxFlat.new()
	border_style.bg_color = Color.TRANSPARENT
	border_style.border_color = Color(0.38, 0.42, 0.5, 1.0)
	border_style.set_border_width_all(1)
	_border.add_theme_stylebox_override("panel", border_style)
	add_child(_border)


func _make_texture_layer() -> TextureRect:
	var texture_layer := TextureRect.new()
	texture_layer.set_anchors_and_offsets_preset(
		Control.PRESET_FULL_RECT
	)
	texture_layer.pivot_offset = CELL_PREVIEW_SIZE * 0.5
	texture_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_layer.stretch_mode = TextureRect.STRETCH_SCALE
	texture_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	texture_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return texture_layer


func _refresh() -> void:
	if _base_texture == null:
		return

	_coordinate_label.text = "%d,%d" % [grid_x, grid_y]
	_zone_label.text = _zone_short_name(zone)
	_zone_overlay.color = _zone_color(zone)

	if cell_visual == null:
		_background.color = Color(0.12, 0.13, 0.16, 0.9)
		_base_texture.texture = null
		_decoration_texture.texture = null
		tooltip_text = (
			"Клетка %d,%d — визуал не назначен"
			% [grid_x, grid_y]
		)
		return

	_background.color = Color(0.12, 0.13, 0.16, 0.08)
	_apply_visual_to_layer(
		_base_texture,
		cell_visual.base_texture
	)
	_apply_visual_to_layer(
		_decoration_texture,
		cell_visual.decoration_texture
	)

	var visual_name := cell_visual.display_name

	if visual_name.strip_edges().is_empty():
		visual_name = cell_visual.cell_visual_id

	tooltip_text = (
		"Клетка %d,%d — %s"
		% [grid_x, grid_y, visual_name]
	)


func _apply_visual_to_layer(
	texture_layer: TextureRect,
	texture: Texture2D
) -> void:
	texture_layer.texture = texture
	texture_layer.modulate = cell_visual.modulate
	texture_layer.flip_h = cell_visual.flip_h
	texture_layer.flip_v = cell_visual.flip_v
	texture_layer.rotation = deg_to_rad(
		float(cell_visual.quarter_turns * 90)
	)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if (
			mouse_event.pressed
			and mouse_event.button_index in [
				MOUSE_BUTTON_LEFT,
				MOUSE_BUTTON_RIGHT
			]
		):
			cell_interacted.emit(
				grid_x,
				grid_y,
				mouse_event.button_index
			)
			accept_event()
		return

	if not event is InputEventMouseMotion:
		return

	var motion_event := event as InputEventMouseMotion

	if (
		motion_event.button_mask
		& MOUSE_BUTTON_MASK_LEFT
	):
		cell_interacted.emit(
			grid_x,
			grid_y,
			MOUSE_BUTTON_LEFT
		)
	elif (
		motion_event.button_mask
		& MOUSE_BUTTON_MASK_RIGHT
	):
		cell_interacted.emit(
			grid_x,
			grid_y,
			MOUSE_BUTTON_RIGHT
		)


func _zone_color(
	zone_value: int
) -> Color:
	match zone_value:
		ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT:
			return Color(0.16, 0.9, 0.35, 0.34)
		ArenaZonePlacementData.Zone.PLAYER_1_MAIN:
			return Color(0.25, 0.65, 1.0, 0.24)
		ArenaZonePlacementData.Zone.NEUTRAL:
			return Color(0.85, 0.82, 0.55, 0.2)
		ArenaZonePlacementData.Zone.PLAYER_2_MAIN:
			return Color(1.0, 0.48, 0.35, 0.24)
		ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT:
			return Color(1.0, 0.2, 0.2, 0.34)
		_:
			return Color.TRANSPARENT


func _zone_short_name(
	zone_value: int
) -> String:
	match zone_value:
		ArenaZonePlacementData.Zone.PLAYER_1_DEPLOYMENT:
			return "D1"
		ArenaZonePlacementData.Zone.PLAYER_1_MAIN:
			return "P1"
		ArenaZonePlacementData.Zone.NEUTRAL:
			return "N"
		ArenaZonePlacementData.Zone.PLAYER_2_MAIN:
			return "P2"
		ArenaZonePlacementData.Zone.PLAYER_2_DEPLOYMENT:
			return "D2"
		_:
			return ""
