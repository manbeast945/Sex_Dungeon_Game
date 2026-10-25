extends DungeonFloor
## Fixed graph: A-B-C-G-H, B-D-E-C loop, and C-F side branch.
const ROOM_SCENES := {
	&"A": preload("res://floors/floor_1/rooms/starter.tscn"),
	&"B": preload("res://floors/floor_1/rooms/root_hall.tscn"),
	&"C": preload("res://floors/floor_1/rooms/moss_junction.tscn"),
	&"D": preload("res://floors/floor_1/rooms/spring_grotto.tscn"),
	&"E": preload("res://floors/floor_1/rooms/fern_chamber.tscn"),
	&"F": preload("res://floors/floor_1/rooms/stone_alcove.tscn"),
	&"G": preload("res://floors/floor_1/rooms/deep_cavern.tscn"),
	&"H": preload("res://floors/floor_1/rooms/descent_chamber.tscn"),
}
const GRID := {
	&"A": Vector2i(0, 0), &"B": Vector2i(1, 0), &"C": Vector2i(2, 0),
	&"D": Vector2i(1, -1), &"E": Vector2i(2, -1), &"F": Vector2i(2, 1),
	&"G": Vector2i(3, 0), &"H": Vector2i(4, 0),
}
const CONNECTIONS := [
	[&"A", &"East", &"B", &"West"], [&"B", &"East", &"C", &"West"],
	[&"B", &"North", &"D", &"South"], [&"D", &"East", &"E", &"West"],
	[&"E", &"South", &"C", &"North"], [&"C", &"South", &"F", &"North"],
	[&"C", &"East", &"G", &"West"], [&"G", &"East", &"H", &"West"],
]

func _ready() -> void:
	for room_id in ROOM_SCENES:
		add_room(ROOM_SCENES[room_id], room_id, Vector2(GRID[room_id]) * Vector2(1280, 720))
	for edge in CONNECTIONS:
		connect_rooms(rooms[edge[0]], edge[1], rooms[edge[2]], edge[3])
	_add_trigger("ReturnToEntrance", Vector2(-580, 0), Vector2(88, 128), _return_to_entrance)
	# Stairs are well inside H, separated from the western arrival point.
	_add_trigger("NextFloorTrigger", Vector2(5120 + 256, 0), Vector2(96, 96), _descend)

func _add_trigger(trigger_name: String, at: Vector2, size: Vector2, callback: Callable) -> void:
	var area := Area2D.new()
	area.name = trigger_name
	area.position = at
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	collision.shape = shape
	area.add_child(collision)
	area.body_entered.connect(callback)
	add_child(area)

func _return_to_entrance(body: Node2D) -> void:
	if body.is_in_group("player"):
		area_transition_requested.emit(&"entrance")

func _descend(body: Node2D) -> void:
	if body.is_in_group("player"):
		next_floor_requested.emit(2)
