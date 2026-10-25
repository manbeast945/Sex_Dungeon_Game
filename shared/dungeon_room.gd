class_name DungeonRoom
extends Node2D

const LAYOUT_GRID_SIZE := 20.0
const FLOOR_TILE_SIZE := 80.0

@export var room_size := Vector2(1280.0, 720.0)
@export var open_sides: Array[Vector2i] = []
@export var generate_rectangular_shell := true
@export var floor_color := Color("#343b43")
@export var wall_color := Color("#76533f")
@export var wall_trim_color := Color("#b8875b")
@export var wall_thickness := 36.0
@export var door_gap := 280.0
@export var door_clearance := 120.0

const SIDE_NAMES := {
	Vector2i(0, -1): &"North",
	Vector2i(1, 0): &"East",
	Vector2i(0, 1): &"South",
	Vector2i(-1, 0): &"West",
}

var entry_point: Marker2D
var doorways: Node2D
var animated_spike_visuals: Array[Node2D] = []
var animation_time := 0.0

func _ready() -> void:
	_snap_room_geometry_to_grid()
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
		_add_themed_props()

func _snap_room_geometry_to_grid() -> void:
	# Room extents use two grid units so a centered room has grid-aligned edges.
	room_size.x = maxf(LAYOUT_GRID_SIZE * 8.0, snappedf(room_size.x, LAYOUT_GRID_SIZE * 2.0))
	room_size.y = maxf(LAYOUT_GRID_SIZE * 8.0, snappedf(room_size.y, LAYOUT_GRID_SIZE * 2.0))
	wall_thickness = maxf(LAYOUT_GRID_SIZE * 2.0, snappedf(wall_thickness, LAYOUT_GRID_SIZE * 2.0))
	door_gap = maxf(LAYOUT_GRID_SIZE * 4.0, snappedf(door_gap, LAYOUT_GRID_SIZE * 2.0))
	door_clearance = maxf(LAYOUT_GRID_SIZE * 2.0, snappedf(door_clearance, LAYOUT_GRID_SIZE))

func snap_local_to_grid(value: Vector2) -> Vector2:
	return Vector2(snappedf(value.x, LAYOUT_GRID_SIZE), snappedf(value.y, LAYOUT_GRID_SIZE))

func _process(delta: float) -> void:
	animation_time += delta
	for index in range(animated_spike_visuals.size()):
		var spikes := animated_spike_visuals[index]
		if is_instance_valid(spikes):
			var pulse := sin(animation_time * 2.2 + index * 1.7)
			spikes.position.y = pulse * 1.5
			spikes.modulate.a = 0.94 + pulse * 0.06

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
	var is_horizontal := rect.size.x >= rect.size.y
	var half_length := (rect.size.x if is_horizontal else rect.size.y) * 0.5
	var visual := Line2D.new()
	visual.points = PackedVector2Array([Vector2(-half_length, 0.0), Vector2(half_length, 0.0)]) if is_horizontal else PackedVector2Array([Vector2(0.0, -half_length), Vector2(0.0, half_length)])
	visual.width = rect.size.y if is_horizontal else rect.size.x
	visual.default_color = wall_color
	visual.begin_cap_mode = Line2D.LINE_CAP_BOX
	visual.end_cap_mode = Line2D.LINE_CAP_BOX
	visual.z_index = 1
	wall.add_child(visual)
	var trim := Line2D.new()
	trim.name = "WallTrim"
	trim.points = visual.points
	trim.width = maxf(4.0, visual.width * 0.11)
	trim.default_color = wall_trim_color
	trim.begin_cap_mode = Line2D.LINE_CAP_BOX
	trim.end_cap_mode = Line2D.LINE_CAP_BOX
	trim.z_index = 2
	wall.add_child(trim)
	add_child(wall)

func _add_themed_props() -> void:
	_add_crate(Vector2(-room_size.x * 0.28, room_size.y * 0.22), 58.0)
	_add_crate(Vector2(room_size.x * 0.31, -room_size.y * 0.2), 50.0)
	_add_spike_patch(Vector2(0.0, room_size.y * 0.2))

func _add_crate(crate_position: Vector2, crate_size: float) -> void:
	var crate := StaticBody2D.new()
	crate.name = "ThemedCrate"
	crate.position = snap_local_to_grid(crate_position)
	crate_size = maxf(LAYOUT_GRID_SIZE * 2.0, snappedf(crate_size, LAYOUT_GRID_SIZE))
	crate.collision_layer = 1
	crate.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(crate_size, crate_size)
	collision.shape = shape
	crate.add_child(collision)
	var box := ColorRect.new()
	box.position = Vector2.ONE * -crate_size * 0.5
	box.size = Vector2.ONE * crate_size
	box.color = wall_color.darkened(0.18)
	crate.add_child(box)
	var horizontal_band := ColorRect.new()
	horizontal_band.position = Vector2(-crate_size * 0.5, -4.0)
	horizontal_band.size = Vector2(crate_size, 8.0)
	horizontal_band.color = wall_trim_color
	crate.add_child(horizontal_band)
	var vertical_band := ColorRect.new()
	vertical_band.position = Vector2(-4.0, -crate_size * 0.5)
	vertical_band.size = Vector2(8.0, crate_size)
	vertical_band.color = wall_trim_color.darkened(0.12)
	crate.add_child(vertical_band)
	add_child(crate)

func _add_spike_patch(patch_position: Vector2, size_multiplier := 1.0) -> void:
	var hazard := Area2D.new()
	hazard.name = "ThemedSpikes"
	hazard.position = snap_local_to_grid(patch_position)
	hazard.collision_layer = 0
	hazard.collision_mask = 1
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(116.0, 50.0) * size_multiplier
	collision.shape = shape
	hazard.add_child(collision)
	var floor_socket := Polygon2D.new()
	floor_socket.name = "SpikeFloorSocket"
	var socket_points := PackedVector2Array([
		Vector2(-61, 0), Vector2(-44, -25), Vector2(0, -34),
		Vector2(45, -25), Vector2(62, 0), Vector2(44, 25),
		Vector2(0, 34), Vector2(-45, 25)
	])
	for point_index in range(socket_points.size()):
		socket_points[point_index] *= size_multiplier
	floor_socket.polygon = socket_points
	floor_socket.color = floor_color.darkened(0.24)
	floor_socket.z_index = 0
	hazard.add_child(floor_socket)

	var spike_cluster := Node2D.new()
	spike_cluster.name = "RaisedSpikeCluster"
	var spike_offsets := PackedVector2Array([
		Vector2(-35, 5), Vector2(0, -4), Vector2(35, 6),
		Vector2(-18, 20), Vector2(20, 21)
	])
	for spike_index in range(spike_offsets.size()):
		var spike := Node2D.new()
		spike.position = spike_offsets[spike_index] * size_multiplier
		var spike_height := (26.0 + float(spike_index % 3) * 5.0) * size_multiplier
		var spike_radius := (10.0 + float(spike_index % 2) * 2.0) * size_multiplier
		var shadow := Polygon2D.new()
		shadow.position = Vector2(5.0, 7.0) * size_multiplier
		shadow.polygon = PackedVector2Array([
			Vector2(-spike_radius, 0.0), Vector2(0.0, -spike_radius * 0.35),
			Vector2(spike_radius, 0.0), Vector2(0.0, spike_radius * 0.35)
		])
		shadow.color = Color(0.0, 0.0, 0.0, 0.48)
		spike.add_child(shadow)
		var left_face := Polygon2D.new()
		left_face.polygon = PackedVector2Array([
			Vector2(0.0, -spike_height), Vector2(-spike_radius, 5.0 * size_multiplier), Vector2(0.0, 10.0 * size_multiplier)
		])
		left_face.color = wall_trim_color.darkened(0.32)
		left_face.z_index = 2
		spike.add_child(left_face)
		var right_face := Polygon2D.new()
		right_face.polygon = PackedVector2Array([
			Vector2(0.0, -spike_height), Vector2(0.0, 10.0 * size_multiplier), Vector2(spike_radius, 5.0 * size_multiplier)
		])
		right_face.color = wall_trim_color.lightened(0.22)
		right_face.z_index = 2
		spike.add_child(right_face)
		var center_highlight := Line2D.new()
		center_highlight.points = PackedVector2Array([Vector2(0.0, -spike_height), Vector2(0.0, 8.0 * size_multiplier)])
		center_highlight.width = maxf(1.5, 2.0 * size_multiplier)
		center_highlight.default_color = wall_trim_color.lightened(0.48)
		center_highlight.z_index = 3
		spike.add_child(center_highlight)
		spike_cluster.add_child(spike)
	spike_cluster.z_index = 2
	hazard.add_child(spike_cluster)
	animated_spike_visuals.append(spike_cluster)
	hazard.body_entered.connect(_on_spikes_body_entered)
	add_child(hazard)

func _on_spikes_body_entered(body: Node2D) -> void:
	if not body.is_in_group("player"):
		return
	var manager := get_parent().get_parent()
	if manager != null and manager.has_method("damage_player"):
		manager.call("damage_player", 10)
