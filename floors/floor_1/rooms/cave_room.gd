@tool
extends DungeonRoom
## Tile layers and their collision are authored in each saved room scene.
@export var room_title := "Cave"
@export var room_id: StringName = &"A"
@export var walkable_cells: Array[Vector2i] = []
@export var blocked_cells: Array[Vector2i] = []
