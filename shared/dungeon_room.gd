class_name DungeonRoom
extends Node2D

@export var room_size := Vector2(1280.0, 720.0)
@export var open_sides: Array[Vector2i] = []
@export var generate_rectangular_shell := true
@export var floor_color := Color("#343b43")
@export var wall_color := Color("#76533f")
@export var wall_trim_color := Color("#b8875b")
@export var wall_thickness := 36.0
@export var door_gap := 150.0
@export var door_clearance := 120.0

const SIDE_NAMES := {
	Vector2i(0, -1): &"North",
	Vector2i(1, 0): &"East",
	Vector2i(0, 1): &"South",
	Vector2i(-1, 0): &"West",
}

var entry_point: Marker2D
var doorways: Node2D

func _ready() -> void:
	entry_point = get_node_or_null("EntryPoint") as Marker2D
	if entry_point == null:
		entry_point = Marker2D.new()
		entry_point.name = "EntryPoint"
		add_child(entry_point)
	doorways = get_node_or_null("Doorways") as Node2D
	if doorways == null:
		doorways = Node2D.new()
		doorways.name = "Doorways"
		add_child(doorways)
	_ensure_doorway_markers()
	if generate_rectangular_shell:
		_add_floor()
		_add_horizontal_wall(-room_size.y * 0.5, _has_open_side(Vector2i(0, -1)))
		_add_horizontal_wall(room_size.y * 0.5 - wall_thickness, _has_open_side(Vector2i(0, 1)))
		_add_vertical_wall(-room_size.x * 0.5, _has_open_side(Vector2i(-1, 0)))
		_add_vertical_wall(room_size.x * 0.5 - wall_thickness, _has_open_side(Vector2i(1, 0)))
		for side in open_sides:
			_add_black_door_void(side)

func get_doorway_marker(doorway_name: StringName) -> Marker2D:
	return doorways.get_node_or_null(NodePath(String(doorway_name))) as Marker2D

func get_arrival_position(doorway_name: StringName) -> Vector2:
	var marker := get_doorway_marker(doorway_name)
	if marker == null:
		push_error("Room %s has no doorway named %s." % [name, doorway_name])
		return global_position
	var arrival := marker.get_node_or_null("ArrivalPoint") as Marker2D
	return arrival.global_position if arrival != null else marker.global_position - _outward_direction(doorway_name) * door_clearance

func get_camera_position() -> Vector2:
	return global_position

func _ensure_doorway_markers() -> void:
	for side in open_sides:
		if not SIDE_NAMES.has(side):
			push_error("Room %s has unsupported doorway side %s." % [name, side])
			continue
		var doorway_name: StringName = SIDE_NAMES[side]
		if get_doorway_marker(doorway_name) != null:
			continue
		var marker := Marker2D.new()
		marker.name = doorway_name
		marker.position = _doorway_position(side)
		marker.rotation = _doorway_rotation(side)
		var arrival := Marker2D.new()
		arrival.name = "ArrivalPoint"
		var arrival_clearance := room_size.x * 0.5 - door_clearance if side.x != 0 else room_size.y * 0.5 - door_clearance
		arrival.position = Vector2(-arrival_clearance, 0.0)
		marker.add_child(arrival)
		doorways.add_child(marker)

func _doorway_position(side: Vector2i) -> Vector2:
	if side.x != 0:
		return Vector2(side.x * (room_size.x * 0.5 - wall_thickness * 0.5), 0.0)
	return Vector2(0.0, side.y * (room_size.y * 0.5 - wall_thickness * 0.5))

func _doorway_rotation(side: Vector2i) -> float:
	return Vector2(side).angle()

func _outward_direction(doorway_name: StringName) -> Vector2:
	match doorway_name:
		&"North": return Vector2.UP
		&"East": return Vector2.RIGHT
		&"South": return Vector2.DOWN
		&"West": return Vector2.LEFT
	return Vector2.RIGHT

func _has_open_side(direction: Vector2i) -> bool:
	return open_sides.has(direction)

func _add_floor() -> void:
	var floor := ColorRect.new()
	floor.name = "Floor"
	floor.position = -room_size * 0.5
	floor.size = room_size
	floor.color = floor_color
	floor.z_index = -2
	add_child(floor)

func _add_black_door_void(direction: Vector2i) -> void:
	var center := _doorway_position(direction)
	var dimensions := Vector2(door_gap, wall_thickness) if direction.y != 0 else Vector2(wall_thickness, door_gap)
	var visual := ColorRect.new()
	visual.name = "BlackDoorVoid"
	visual.position = center - dimensions * 0.5
	visual.size = dimensions
	visual.color = Color.BLACK
	visual.z_index = 1
	add_child(visual)

func _add_horizontal_wall(y: float, has_door: bool) -> void:
	if not has_door:
		_add_wall(Rect2(-room_size.x * 0.5, y, room_size.x, wall_thickness))
		return
	var segment_width := (room_size.x - door_gap) * 0.5
	_add_wall(Rect2(-room_size.x * 0.5, y, segment_width, wall_thickness))
	_add_wall(Rect2(door_gap * 0.5, y, segment_width, wall_thickness))

func _add_vertical_wall(x: float, has_door: bool) -> void:
	if not has_door:
		_add_wall(Rect2(x, -room_size.y * 0.5, wall_thickness, room_size.y))
		return
	var segment_height := (room_size.y - door_gap) * 0.5
	_add_wall(Rect2(x, -room_size.y * 0.5, wall_thickness, segment_height))
	_add_wall(Rect2(x, door_gap * 0.5, wall_thickness, segment_height))

func _add_wall(rect: Rect2) -> void:
	var wall := StaticBody2D.new()
	wall.position = rect.position + rect.size * 0.5
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collision.shape = shape
	wall.add_child(collision)
	var visual := ColorRect.new()
	visual.position = -rect.size * 0.5
	visual.size = rect.size
	visual.color = wall_color
	visual.z_index = 1
	wall.add_child(visual)
	var trim := ColorRect.new()
	trim.name = "WallTrim"
	trim.color = wall_trim_color
	trim.z_index = 2
	if rect.size.x >= rect.size.y:
		trim.position = Vector2(-rect.size.x * 0.5, rect.size.y * 0.5 - 5.0)
		trim.size = Vector2(rect.size.x, 5.0)
	else:
		trim.position = Vector2(rect.size.x * 0.5 - 5.0, -rect.size.y * 0.5)
		trim.size = Vector2(5.0, rect.size.y)
	wall.add_child(trim)
	add_child(wall)


