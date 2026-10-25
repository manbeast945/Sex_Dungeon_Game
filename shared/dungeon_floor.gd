class_name DungeonFloor
extends Node2D

signal room_transition_requested(player_position: Vector2, camera_position: Vector2)
signal next_floor_requested(floor_number: int)

@export var entry_marker_path: NodePath = ^"EntryPoint"

var rooms: Dictionary = {}
var live_map_marker: ColorRect
var live_map_world_min := Vector2.ZERO
var live_map_offset := Vector2.ZERO
var live_map_scale := 1.0

func snap_world_to_grid(value: Vector2) -> Vector2:
	return Vector2(snappedf(value.x, DungeonRoom.LAYOUT_GRID_SIZE), snappedf(value.y, DungeonRoom.LAYOUT_GRID_SIZE))

func random_grid_distance(random: RandomNumberGenerator, minimum: float, maximum: float) -> float:
	var min_cells := ceili(minimum / DungeonRoom.LAYOUT_GRID_SIZE)
	var max_cells := floori(maximum / DungeonRoom.LAYOUT_GRID_SIZE)
	return float(random.randi_range(min_cells, maxi(min_cells, max_cells))) * DungeonRoom.LAYOUT_GRID_SIZE

func _process(_delta: float) -> void:
	if live_map_marker == null:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null:
		live_map_marker.position = _world_to_live_map(player.global_position) - live_map_marker.size * 0.5

func get_entry_position() -> Vector2:
	var marker := get_node_or_null(entry_marker_path) as Node2D
	if marker == null:
		push_error("Floor %s is missing its EntryPoint marker." % name)
		return global_position
	return marker.global_position

func add_room(room_scene: PackedScene, instance_name: StringName, room_origin: Vector2) -> DungeonRoom:
	if room_scene == null:
		push_error("Cannot add room %s: its scene is missing." % instance_name)
		return null
	var room := room_scene.instantiate() as DungeonRoom
	if room == null:
		push_error("Room scene %s must use the DungeonRoom root contract." % instance_name)
		return null
	room.name = instance_name
	room.position = room_origin
	add_child(room)
	rooms[instance_name] = room
	return room

func connect_rooms(room_a: DungeonRoom, exit_a: StringName, room_b: DungeonRoom, exit_b: StringName) -> void:
	if room_a == null or room_b == null:
		push_error("Room connection endpoints must both be valid DungeonRoom instances.")
		return
	var marker_a := room_a.get_doorway_marker(exit_a)
	var marker_b := room_b.get_doorway_marker(exit_b)
	if marker_a == null or marker_b == null:
		push_error("Cannot connect %s/%s to %s/%s: check each room's Doorways markers." % [room_a.name, exit_a, room_b.name, exit_b])
		return
	_add_hallway(room_a, marker_a, room_b, marker_b)

func place_room_at_exit(room_a: DungeonRoom, exit_a: StringName, room_b: DungeonRoom, exit_b: StringName, hallway_length: float) -> void:
	var marker_a := room_a.get_doorway_marker(exit_a)
	var marker_b := room_b.get_doorway_marker(exit_b)
	if marker_a == null or marker_b == null:
		push_error("Cannot place connected rooms because a doorway marker is missing.")
		return
	var outward_a := marker_a.global_transform.x.normalized()
	var outward_b := marker_b.global_transform.x.normalized()
	if outward_a.dot(outward_b) > -0.98:
		push_error("Doorways %s/%s and %s/%s must face one another." % [room_a.name, exit_a, room_b.name, exit_b])
		return
	var marker_b_offset := marker_b.global_position - room_b.global_position
	var target_marker_position := marker_a.global_position + outward_a * snappedf(hallway_length, DungeonRoom.LAYOUT_GRID_SIZE)
	room_b.global_position = snap_world_to_grid(target_marker_position - marker_b_offset)
	# Re-read the transformed marker and remove any rounding residue. Connections must
	# share one exact axis or a visible crack can appear at the doorway.
	room_b.global_position += target_marker_position - marker_b.global_position
	room_b.global_position = snap_world_to_grid(room_b.global_position)

func set_room_doors_enabled(enabled: bool) -> void:
	# Hallways are always open. This remains as a compatibility hook for floors.
	pass

func build_live_minimap(map_rooms: Array, map_connections: Array, panel_color := Color("#0b0d13e8"), border_color := Color("#bdc8d8")) -> void:
	var outlines: Array[PackedVector2Array] = []
	var first_point := true
	var world_max := Vector2.ZERO
	for room_node in map_rooms:
		var room := room_node as DungeonRoom
		if room == null:
			continue
		var outline := _get_room_world_outline(room)
		outlines.append(outline)
		for point in outline:
			if first_point:
				live_map_world_min = point
				world_max = point
				first_point = false
			else:
				live_map_world_min.x = minf(live_map_world_min.x, point.x)
				live_map_world_min.y = minf(live_map_world_min.y, point.y)
				world_max.x = maxf(world_max.x, point.x)
				world_max.y = maxf(world_max.y, point.y)
	if first_point:
		return
	var panel_size := Vector2(270.0, 156.0)
	var content_size := panel_size - Vector2(24.0, 24.0)
	var world_span := world_max - live_map_world_min
	world_span.x = maxf(world_span.x, 1.0)
	world_span.y = maxf(world_span.y, 1.0)
	live_map_scale = minf(content_size.x / world_span.x, content_size.y / world_span.y)
	live_map_offset = Vector2(12.0, 12.0) + (content_size - world_span * live_map_scale) * 0.5

	var canvas := CanvasLayer.new()
	canvas.name = "GeneratedMinimap"
	canvas.layer = 5
	add_child(canvas)
	var panel := ColorRect.new()
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-panel_size.x - 20.0, 24.0)
	panel.size = panel_size
	panel.color = panel_color
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(panel)

	for connection_data in map_connections:
		var connection := connection_data as Array
		if connection.size() != 4:
			continue
		var room_a := connection[0] as DungeonRoom
		var room_b := connection[2] as DungeonRoom
		var marker_a := room_a.get_doorway_marker(connection[1])
		var marker_b := room_b.get_doorway_marker(connection[3])
		if marker_a == null or marker_b == null:
			continue
		var route := Line2D.new()
		route.points = PackedVector2Array([_world_to_live_map(marker_a.global_position), _world_to_live_map(marker_b.global_position)])
		route.width = clampf(room_a.door_gap * marker_a.global_transform.y.length() * live_map_scale, 3.0, 11.0)
		route.default_color = Color(border_color, 0.58)
		route.begin_cap_mode = Line2D.LINE_CAP_BOX
		route.end_cap_mode = Line2D.LINE_CAP_BOX
		panel.add_child(route)

	for room_index in range(outlines.size()):
		var room := map_rooms[room_index] as DungeonRoom
		var mapped_outline := PackedVector2Array()
		for point in outlines[room_index]:
			mapped_outline.append(_world_to_live_map(point))
		var fill := Polygon2D.new()
		fill.polygon = mapped_outline
		fill.color = room.floor_color.lightened(0.08)
		panel.add_child(fill)
		var outline_line := Line2D.new()
		outline_line.points = mapped_outline
		outline_line.closed = true
		outline_line.width = 2.0
		outline_line.default_color = Color(room.wall_trim_color, 0.9)
		panel.add_child(outline_line)

	live_map_marker = ColorRect.new()
	live_map_marker.size = Vector2(8.0, 8.0)
	live_map_marker.color = Color.WHITE
	live_map_marker.z_index = 10
	panel.add_child(live_map_marker)

func _get_room_world_outline(room: DungeonRoom) -> PackedVector2Array:
	var local_outline := PackedVector2Array()
	if room.has_method("_build_uvs"):
		var irregular_outline: Variant = room.get("room_polygon")
		if irregular_outline is PackedVector2Array:
			local_outline = irregular_outline
	if local_outline.is_empty():
		var half_size := room.room_size * 0.5
		local_outline = PackedVector2Array([
			Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
			Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)
		])
	var world_outline := PackedVector2Array()
	for point in local_outline:
		world_outline.append(room.to_global(point))
	return world_outline

func _world_to_live_map(world_position: Vector2) -> Vector2:
	return live_map_offset + (world_position - live_map_world_min) * live_map_scale

func _add_hallway(room_a: DungeonRoom, marker_a: Marker2D, room_b: DungeonRoom, marker_b: Marker2D) -> void:
	# Use the same snapped doorway coordinates for visuals and collision. This
	# prevents tiny transform fractions from producing diagonal or disconnected halls.
	var start := to_local(snap_world_to_grid(marker_a.global_position))
	var end := to_local(snap_world_to_grid(marker_b.global_position))
	var offset := end - start
	if not is_zero_approx(offset.x) and not is_zero_approx(offset.y):
		push_error("Hallway from %s to %s is diagonal. Align connected room doorways before connecting them." % [room_a.name, room_b.name])
		return
	var is_horizontal := absf(offset.x) >= absf(offset.y)
	var length := absf(offset.x if is_horizontal else offset.y)
	if length <= 0.0:
		return
	var width_a := room_a.door_gap * marker_a.global_transform.y.length()
	var width_b := room_b.door_gap * marker_b.global_transform.y.length()
	var width := minf(width_a, width_b)
	var center := (start + end) * 0.5
	var hallway := Node2D.new()
	hallway.name = "Hallway_%s_to_%s" % [room_a.name, room_b.name]
	hallway.position = center
	add_child(hallway)

	var floor := ColorRect.new()
	floor.name = "Floor"
	floor.size = Vector2(length, width) if is_horizontal else Vector2(width, length)
	floor.position = -floor.size * 0.5
	floor.color = room_a.floor_color
	floor.z_index = -2
	hallway.add_child(floor)
	_add_floor_color_blend(hallway, floor.size, is_horizontal, start, end, room_a.floor_color, room_b.floor_color)

	var scaled_wall_thickness := room_a.wall_thickness * marker_a.global_transform.y.length()
	var wall_span := Vector2(length, scaled_wall_thickness) if is_horizontal else Vector2(scaled_wall_thickness, length)
	var side_offset := Vector2(0.0, width * 0.5) if is_horizontal else Vector2(width * 0.5, 0.0)
	var a_is_negative := start.x < end.x if is_horizontal else start.y < end.y
	_add_hallway_wall(hallway, -side_offset, wall_span, room_a, room_b, a_is_negative)
	_add_hallway_wall(hallway, side_offset, wall_span, room_a, room_b, a_is_negative)
	if room_a.has_method("decorate_hallway"):
		room_a.call("decorate_hallway", hallway, floor.size, is_horizontal, room_b, a_is_negative)

func _add_floor_color_blend(hallway: Node2D, floor_size: Vector2, is_horizontal: bool, start: Vector2, end: Vector2, color_a: Color, color_b: Color) -> void:
	var half_size := floor_size * 0.5
	var negative_color := color_a
	var positive_color := color_b
	var a_is_negative := start.x < end.x if is_horizontal else start.y < end.y
	if not a_is_negative:
		negative_color = color_b
		positive_color = color_a
	var blend := Polygon2D.new()
	blend.name = "FloorThemeBlend"
	blend.polygon = PackedVector2Array([
		Vector2(-half_size.x, -half_size.y), Vector2(half_size.x, -half_size.y),
		Vector2(half_size.x, half_size.y), Vector2(-half_size.x, half_size.y)
	])
	blend.vertex_colors = PackedColorArray([
		negative_color,
		positive_color if is_horizontal else negative_color,
		positive_color,
		negative_color if is_horizontal else positive_color,
	])
	blend.z_index = -1
	hallway.add_child(blend)

func _add_hallway_wall(hallway: Node2D, wall_position: Vector2, wall_size: Vector2, room_a: DungeonRoom, room_b: DungeonRoom, a_is_negative: bool) -> void:
	var wall := StaticBody2D.new()
	wall.position = wall_position
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = wall_size
	collision.shape = shape
	wall.add_child(collision)
	var is_horizontal := wall_size.x >= wall_size.y
	var half_length := (wall_size.x if is_horizontal else wall_size.y) * 0.5
	var visual := Line2D.new()
	visual.name = "HallwayRockBorder"
	visual.points = PackedVector2Array([Vector2(-half_length, 0.0), Vector2(half_length, 0.0)]) if is_horizontal else PackedVector2Array([Vector2(0.0, -half_length), Vector2(0.0, half_length)])
	visual.width = wall_size.y if is_horizontal else wall_size.x
	visual.gradient = _make_corridor_gradient(room_a.wall_color, room_b.wall_color, a_is_negative)
	visual.begin_cap_mode = Line2D.LINE_CAP_NONE
	visual.end_cap_mode = Line2D.LINE_CAP_NONE
	visual.z_index = 1
	wall.add_child(visual)
	var trim := Line2D.new()
	trim.name = "HallwayGlowTrim"
	trim.points = visual.points
	trim.width = maxf(4.0, visual.width * 0.11)
	trim.gradient = _make_corridor_gradient(room_a.wall_trim_color, room_b.wall_trim_color, a_is_negative)
	trim.begin_cap_mode = Line2D.LINE_CAP_NONE
	trim.end_cap_mode = Line2D.LINE_CAP_NONE
	trim.z_index = 2
	wall.add_child(trim)
	hallway.add_child(wall)

func _make_corridor_gradient(color_a: Color, color_b: Color, a_is_negative: bool) -> Gradient:
	var gradient := Gradient.new()
	gradient.set_color(0, color_a if a_is_negative else color_b)
	gradient.set_color(1, color_b if a_is_negative else color_a)
	return gradient
