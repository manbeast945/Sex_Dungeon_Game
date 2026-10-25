class_name FloorTwoAbstractRoom
extends DungeonRoom

@export var room_polygon := PackedVector2Array()
@export var accent_color := Color("#f2efff")
@export var darkness := 0.72
@export var art_flip_h := false
@export var decor_seed := 2
@export var geometry_scale := 1.0
@export var pillar_centers := PackedVector2Array()
@export var pillar_radii := PackedFloat32Array()

var animated_hallway_glows: Array[Line2D] = []
var cave_prop_positions := PackedVector2Array()

func _ready() -> void:
	_apply_geometry_scale()
	_snap_cave_geometry_to_grid()
	generate_rectangular_shell = false
	super()
	_build_clipped_cave_floor()
	_build_irregular_wall()
	_build_doorway_tunnels()
	_build_stone_pillars()
	_build_cave_props()

func _snap_cave_geometry_to_grid() -> void:
	room_size.x = snappedf(room_size.x, LAYOUT_GRID_SIZE * 2.0)
	room_size.y = snappedf(room_size.y, LAYOUT_GRID_SIZE * 2.0)
	wall_thickness = snappedf(wall_thickness, LAYOUT_GRID_SIZE * 2.0)
	door_gap = snappedf(door_gap, LAYOUT_GRID_SIZE * 2.0)
	for index in range(room_polygon.size()):
		room_polygon[index] = snap_local_to_grid(room_polygon[index])
	for index in range(pillar_centers.size()):
		pillar_centers[index] = snap_local_to_grid(pillar_centers[index])
	for index in range(pillar_radii.size()):
		pillar_radii[index] = maxf(LAYOUT_GRID_SIZE, snappedf(pillar_radii[index], LAYOUT_GRID_SIZE))

func _process(delta: float) -> void:
	super(delta)
	for index in range(animated_hallway_glows.size()):
		var glow := animated_hallway_glows[index]
		if is_instance_valid(glow):
			glow.modulate.a = 0.62 + sin(animation_time * 1.8 + index) * 0.24

func _apply_geometry_scale() -> void:
	if is_equal_approx(geometry_scale, 1.0):
		return
	room_size *= geometry_scale
	wall_thickness *= geometry_scale
	# Use the same doorway cell count in every cave so connected corridors have
	# one continuous width without exposed shoulders at either end.
	door_gap = 280.0 * geometry_scale
	for index in range(room_polygon.size()):
		room_polygon[index] *= geometry_scale
	for index in range(pillar_centers.size()):
		pillar_centers[index] *= geometry_scale
	for index in range(pillar_radii.size()):
		pillar_radii[index] *= geometry_scale
	var authored_entry := get_node_or_null("EntryPoint") as Marker2D
	if authored_entry != null:
		authored_entry.position *= geometry_scale

func _build_clipped_cave_floor() -> void:
	var floor_base := Polygon2D.new()
	floor_base.name = "FloorTwoBase"
	floor_base.polygon = room_polygon
	floor_base.color = floor_color
	floor_base.z_index = -6
	add_child(floor_base)

func _build_irregular_wall() -> void:
	for index in range(room_polygon.size()):
		var start := room_polygon[index]
		var finish := room_polygon[(index + 1) % room_polygon.size()]
		var cut_interval := _doorway_cut_interval(start, finish)
		if cut_interval.x < 0.0:
			_add_wall_segment(start, finish)
			continue
		_add_wall_segment(start, start.lerp(finish, cut_interval.x))
		_add_wall_segment(start.lerp(finish, cut_interval.y), finish)

func _doorway_cut_interval(start: Vector2, finish: Vector2) -> Vector2:
	var edge := finish - start
	var edge_length := edge.length()
	if edge_length <= 0.001:
		return Vector2(-1.0, -1.0)
	var edge_direction := edge / edge_length
	for child in doorways.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		var doorway_outward := Vector2.RIGHT.rotated(marker.rotation)
		var doorway_tangent := doorway_outward.orthogonal()
		if absf(edge_direction.dot(doorway_tangent)) < 0.95:
			continue
		var marker_delta := marker.position - start
		var perpendicular_distance := absf(marker_delta.cross(edge_direction))
		if perpendicular_distance > wall_thickness * 1.25:
			continue
		var center_distance := marker_delta.dot(edge_direction)
		var cut_start := (center_distance - door_gap * 0.5) / edge_length
		var cut_end := (center_distance + door_gap * 0.5) / edge_length
		if cut_end > 0.0 and cut_start < 1.0:
			return Vector2(clampf(cut_start, 0.0, 1.0), clampf(cut_end, 0.0, 1.0))
	return Vector2(-1.0, -1.0)

func _add_wall_segment(start: Vector2, finish: Vector2) -> void:
	var length := start.distance_to(finish)
	if length < wall_thickness * 0.12:
		return
	var midpoint := (start + finish) * 0.5
	var wall := StaticBody2D.new()
	wall.name = "WallSegment"
	wall.position = midpoint
	wall.rotation = (finish - start).angle()
	wall.collision_layer = 1
	wall.collision_mask = 0
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	# Square overlap at each end creates a solid pixel-art corner.
	shape.size = Vector2(length + wall_thickness * 1.38, wall_thickness * 1.63)
	collision.shape = shape
	collision.position.y = wall_thickness * 0.295
	wall.add_child(collision)
	add_child(wall)

	var local_start := Vector2(-length * 0.5, 0.0)
	var local_finish := Vector2(length * 0.5, 0.0)
	var depth_shadow := Line2D.new()
	depth_shadow.position = Vector2(0.0, wall_thickness * 0.42)
	depth_shadow.points = PackedVector2Array([local_start, local_finish])
	depth_shadow.width = wall_thickness * 1.38
	depth_shadow.default_color = Color("#010102")
	depth_shadow.joint_mode = Line2D.LINE_JOINT_SHARP
	depth_shadow.begin_cap_mode = Line2D.LINE_CAP_BOX
	depth_shadow.end_cap_mode = Line2D.LINE_CAP_BOX
	depth_shadow.z_index = 1
	wall.add_child(depth_shadow)
	var rock_face := Line2D.new()
	rock_face.points = PackedVector2Array([local_start, local_finish])
	rock_face.width = wall_thickness * 1.04
	rock_face.default_color = Color("#111116")
	rock_face.joint_mode = Line2D.LINE_JOINT_SHARP
	rock_face.begin_cap_mode = Line2D.LINE_CAP_BOX
	rock_face.end_cap_mode = Line2D.LINE_CAP_BOX
	rock_face.z_index = 2
	wall.add_child(rock_face)
	var glow := Line2D.new()
	glow.points = PackedVector2Array([local_start, local_finish])
	glow.width = maxf(6.0, wall_thickness * 0.055)
	glow.default_color = Color(accent_color, 0.62)
	glow.z_index = 3
	wall.add_child(glow)

func _build_doorway_tunnels() -> void:
	for child in doorways.get_children():
		var marker := child as Marker2D
		if marker == null:
			continue
		var outward := Vector2.RIGHT.rotated(marker.rotation)
		var side := outward.orthogonal() * door_gap * 0.49
		var inner := marker.position - outward * (175.0 * geometry_scale)
		# Stop precisely on the doorway plane. The generated hallway begins here;
		# extending both borders past this point created doubled, messy entrances.
		var outer := marker.position
		var tunnel := Polygon2D.new()
		tunnel.name = "ThemedTunnel_%s" % marker.name
		tunnel.polygon = PackedVector2Array([inner - side, outer - side, outer + side, inner + side])
		tunnel.color = Color("#07070a")
		tunnel.z_index = -1
		add_child(tunnel)
		_add_wall_segment(inner - side, outer - side)
		_add_wall_segment(inner + side, outer + side)

func _build_stone_pillars() -> void:
	for pillar_index in range(mini(pillar_centers.size(), pillar_radii.size())):
		var center := pillar_centers[pillar_index]
		var radius := pillar_radii[pillar_index]
		var block_points := _pixel_rock_polygon(radius)
		var body := StaticBody2D.new()
		body.position = center
		body.collision_layer = 1
		body.collision_mask = 0
		var collision := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = Vector2.ONE * radius * 1.7
		collision.shape = shape
		body.add_child(collision)
		add_child(body)

		var shadow := Polygon2D.new()
		shadow.position = center + Vector2(0.0, radius * 0.48)
		shadow.polygon = _pixel_rock_polygon(radius * 1.12)
		shadow.color = Color(0.0, 0.0, 0.0, 0.84)
		shadow.z_index = 1
		add_child(shadow)
		var column := Polygon2D.new()
		column.position = center
		column.polygon = block_points
		column.color = Color("#0d0d12")
		column.z_index = 2
		add_child(column)
		var rim := Line2D.new()
		rim.position = center
		rim.points = block_points
		rim.closed = true
		rim.width = maxf(7.0, radius * 0.055)
		rim.default_color = Color(accent_color, 0.64)
		rim.joint_mode = Line2D.LINE_JOINT_SHARP
		rim.z_index = 3
		add_child(rim)

func _build_cave_props() -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	var crate_position := _find_open_prop_position(random, 0)
	if crate_position != Vector2.INF:
		cave_prop_positions.append(crate_position)
		_add_crate(crate_position, random.randf_range(42.0, 54.0) * geometry_scale)
	if random.randf() < 0.45:
		var second_crate_position := _find_open_prop_position(random, 1)
		if second_crate_position != Vector2.INF:
			cave_prop_positions.append(second_crate_position)
			_add_crate(second_crate_position, random.randf_range(38.0, 48.0) * geometry_scale)
	var spike_position := _find_open_prop_position(random, 2)
	if spike_position != Vector2.INF:
		cave_prop_positions.append(spike_position)
		_add_spike_patch(spike_position, geometry_scale * 0.85)

func _find_open_prop_position(random: RandomNumberGenerator, salt: int) -> Vector2:
	for _attempt in range(30):
		var candidate := Vector2(
			random.randf_range(-room_size.x * 0.28, room_size.x * 0.28),
			random.randf_range(-room_size.y * 0.25, room_size.y * 0.25)
		)
		candidate += Vector2(salt * 31.0, -salt * 19.0)
		candidate = snap_local_to_grid(candidate)
		if not Geometry2D.is_point_in_polygon(candidate, room_polygon):
			continue
		if entry_point != null and candidate.distance_to(entry_point.position) < 520.0:
			continue
		var too_close_to_prop := false
		for placed_position in cave_prop_positions:
			if candidate.distance_to(placed_position) < 420.0:
				too_close_to_prop = true
				break
		if too_close_to_prop:
			continue
		var blocked := false
		for marker_node in doorways.get_children():
			var marker := marker_node as Marker2D
			if marker != null and candidate.distance_to(marker.position) < door_gap * 0.8:
				blocked = true
				break
		if not blocked:
			return candidate
	return Vector2.INF

func decorate_hallway(hallway: Node2D, hallway_size: Vector2, is_horizontal: bool, destination_room: DungeonRoom, source_is_negative: bool) -> void:
	var half_size := hallway_size * 0.5
	var destination_accent := accent_color
	if destination_room != null:
		var destination_value: Variant = destination_room.get("accent_color")
		if destination_value is Color:
			destination_accent = destination_value
	for side in [-1.0, 1.0]:
		var glow := Line2D.new()
		if is_horizontal:
			glow.points = PackedVector2Array([Vector2(-half_size.x, side * half_size.y), Vector2(half_size.x, side * half_size.y)])
		else:
			glow.points = PackedVector2Array([Vector2(side * half_size.x, -half_size.y), Vector2(side * half_size.x, half_size.y)])
		glow.width = maxf(5.0, wall_thickness * 0.05)
		glow.gradient = Gradient.new()
		glow.gradient.set_color(0, Color(accent_color if source_is_negative else destination_accent, 0.7))
		glow.gradient.set_color(1, Color(destination_accent if source_is_negative else accent_color, 0.7))
		glow.z_index = 3
		hallway.add_child(glow)
		animated_hallway_glows.append(glow)

func _pixel_rock_polygon(radius: float) -> PackedVector2Array:
	var notch := snappedf(radius * 0.45, LAYOUT_GRID_SIZE)
	var extent := snappedf(radius, LAYOUT_GRID_SIZE)
	return PackedVector2Array([
		Vector2(-notch, -extent), Vector2(notch, -extent),
		Vector2(extent, -notch), Vector2(extent, notch),
		Vector2(notch, extent), Vector2(-notch, extent),
		Vector2(-extent, notch), Vector2(-extent, -notch)
	])
