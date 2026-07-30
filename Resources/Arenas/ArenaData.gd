extends Resource

class_name ArenaData


# ============================================================
# ИДЕНТИФИКАЦИЯ
# ============================================================

@export var arena_id: String = ""

@export var arena_name: String = ""

@export_multiline var description: String = ""


# ============================================================
# РАЗМЕР ПОЛЯ
# ============================================================

@export_range(1, 32, 1) var width: int = 7

@export_range(1, 32, 1) var height: int = 5


# ============================================================
# ВИЗУАЛЬНЫЙ СЛОЙ
# ============================================================

@export var biome: BiomeVisualData = null

@export var default_cell_visual: CellVisualData = null

@export var visual_placements: Array[ArenaCellVisualPlacementData] = []

@export var background_color: Color = Color(0.08, 0.08, 0.1, 1.0)

@export var background_texture: Texture2D = null

@export var background_modulate: Color = Color.WHITE

@export var background_scale: Vector2 = Vector2.ONE

@export var background_offset: Vector2 = Vector2.ZERO


# ============================================================
# ЛОГИЧЕСКИЙ СЛОЙ ЗОН
# ============================================================

@export var default_zone: ArenaZonePlacementData.Zone = (
	ArenaZonePlacementData.Zone.NEUTRAL
)

@export var zone_placements: Array[ArenaZonePlacementData] = []

@export_range(1, 6, 1) var player_1_deployment_capacity: int = 6

@export_range(1, 6, 1) var player_2_deployment_capacity: int = 6


# ============================================================
# ОБЪЕКТЫ АРЕНЫ
# ============================================================

@export var object_placements: Array[ArenaObjectPlacementData] = []


# ============================================================
# ПОЛУЧЕНИЕ ДАННЫХ КЛЕТКИ
# ============================================================

func get_cell_visual_at(
	x: int,
	y: int
) -> CellVisualData:
	for placement in visual_placements:
		if placement == null:
			continue

		if placement.x == x and placement.y == y:
			return placement.cell_visual

	if default_cell_visual != null:
		return default_cell_visual

	if biome != null:
		return biome.default_cell_visual

	return null


func get_zone_at(
	x: int,
	y: int
) -> ArenaZonePlacementData.Zone:
	for placement in zone_placements:
		if placement == null:
			continue

		if placement.x == x and placement.y == y:
			return placement.zone

	return default_zone
