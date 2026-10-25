extends SceneTree
## Editor authoring tool: regenerates editable TileMapLayer scenes and TileSet.
## Run Godot --headless --path . --script res://floors/floor_1/tools/build_rooms.gd
const DIR := "res://floors/floor_1/"
const SPECS := [
	["A", "Forest Threshold", "starter", ["West", "East"], 15.0, 8.5, 0.70],
	["B", "Root Hall", "root_hall", ["West", "East", "North"], 14.0, 8.0, 0.50],
	["C", "Moss Junction", "moss_junction", ["West", "East", "North", "South"], 16.0, 9.0, 0.38],
	["D", "Spring Grotto", "spring_grotto", ["South", "East"], 14.5, 8.8, 0.62],
	["E", "Fern Chamber", "fern_chamber", ["West", "South"], 15.0, 8.6, 0.78],
	["F", "Stone Alcove", "stone_alcove", ["North"], 12.8, 8.0, 0.16],
	["G", "Deep Cavern", "deep_cavern", ["West", "East"], 17.0, 9.1, 0.18],
	["H", "Descent Chamber", "descent_chamber", ["West"], 14.0, 8.1, 0.08],
]
var tiles: TileSet

func _initialize() -> void:
	call_deferred("_build")

func _build() -> void:
	tiles = TileSet.new()
	tiles.tile_size = Vector2i(16, 16)
	tiles.add_physics_layer()
	tiles.set_physics_layer_collision_layer(0, 1)
	tiles.set_physics_layer_collision_mask(0, 0)
	var atlas := TileSetAtlasSource.new()
	atlas.texture = load(DIR + "art/cave_tiles.svg") as Texture2D
	atlas.texture_region_size = Vector2i(16, 16)
	tiles.add_source(atlas, 0)
	for id in 64:
		var cell := Vector2i(id % 16, id / 16)
		atlas.create_tile(cell)
		if (id >= 8 and id < 20) or (id >= 24 and id < 28) or (id >= 44 and id < 48):
			var data := atlas.get_tile_data(cell, 0)
			data.set_collision_polygons_count(0, 1)
			data.set_collision_polygon_points(0, 0, PackedVector2Array([Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)]))
	if ResourceSaver.save(tiles, DIR + "art/cave_tileset.tres") != OK:
		quit(1)
		return
	tiles = load(DIR + "art/cave_tileset.tres") as TileSet
	for index in SPECS.size():
		_build_room(SPECS[index], index)
	print("AUTHORED: eight room scenes and native 16px TileSet")
	quit()

func _own(node: Node, parent: Node, scene: Node) -> void:
	parent.add_child(node)
	node.owner = scene

func _layer(label: String, scene: Node2D, depth: int) -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = label
	layer.tile_set = tiles
	# Preserve each authored tile collider; merged quadrants drop isolated cells in 4.7.2.
	layer.physics_quadrant_size = 1
	layer.position = Vector2(-640, -384)
	layer.scale = Vector2(2, 2)
	layer.z_index = depth
	layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_own(layer, scene, scene)
	return layer

func _put(layer: TileMapLayer, cell: Vector2i, id: int) -> void:
	layer.set_cell(cell, 0, Vector2i(id % 16, id / 16))

func _build_room(spec: Array, index: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 94510 + index
	var scene := Node2D.new()
	scene.set_script(load(DIR + "rooms/cave_room.gd"))
	scene.name = spec[2].to_pascal_case()
	scene.set("room_title", spec[1])
	scene.set("room_id", StringName(spec[0]))
	scene.set("generate_rectangular_shell", false)
	scene.set("door_gap", 128.0)
	scene.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var entry := Marker2D.new()
	entry.name = "EntryPoint"
	_own(entry, scene, scene)
	var doorways := Node2D.new()
	doorways.name = "Doorways"
	_own(doorways, scene, scene)
	for side in spec[3]:
		var direction: Vector2 = {"West": Vector2.LEFT, "East": Vector2.RIGHT, "North": Vector2.UP, "South": Vector2.DOWN}[side]
		var marker := Marker2D.new()
		marker.name = side
		marker.position = direction * (622.0 if direction.x else 342.0)
		marker.rotation = direction.angle()
		_own(marker, doorways, scene)
		var arrival := Marker2D.new()
		arrival.name = "ArrivalPoint"
		arrival.position = Vector2(-142 if direction.x else -134, 0)
		_own(arrival, marker, scene)
	var terrain := _layer("Terrain", scene, -10)
	var obstacles := _layer("WallsWaterAndBoulders", scene, -8)
	var vegetation := _layer("RootsFernsAndFlowers", scene, -6)
	var walkable: Dictionary = {}
	for y in 24:
		for x in 40:
			var p := Vector2((x - 19.5) / spec[4], (y - 11.5) / spec[5])
			var outline := 1.0 + sin(y * 1.14 + index * 1.7) * 0.12 + cos(x * 0.76 + index) * 0.10
			var inside := p.length_squared() <= outline
			if y >= 10 and y <= 13:
				inside = inside or (x <= 20 and "West" in spec[3]) or (x >= 19 and "East" in spec[3])
			if x >= 18 and x <= 21:
				inside = inside or (y <= 12 and "North" in spec[3]) or (y >= 11 and "South" in spec[3])
			if inside:
				walkable[Vector2i(x, y)] = true
	var blocked: Array[Vector2i] = []
	for y in 24:
		for x in 40:
			var cell := Vector2i(x, y)
			if not walkable.has(cell):
				var near := false
				for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					near = near or walkable.has(cell + offset)
				var id := 44 + rng.randi_range(0, 3)
				if near:
					id = (12 if walkable.has(cell + Vector2i.DOWN) else 8) + rng.randi_range(0, 3)
				_put(obstacles, cell, id)
				continue
			var path: bool = (y >= 10 and y <= 13) or (x >= 18 and x <= 21 and ("North" in spec[3] or "South" in spec[3]))
			var ground := rng.randi_range(0, 3)
			if not path and rng.randf() < spec[6]:
				ground = rng.randi_range(4, 7)
			elif path and rng.randf() < 0.7:
				ground = rng.randi_range(40, 43)
			if index >= 5:
				ground = rng.randi_range(48, 51) if ground < 4 or path else ground
			_put(terrain, cell, ground)
			var perimeter := false
			for offset in [Vector2i(-2, 0), Vector2i(2, 0), Vector2i(0, -2), Vector2i(0, 2)]:
				perimeter = perimeter or not walkable.has(cell + offset)
			# Keep all central routes and doorway arrival zones generously clear.
			if not path and perimeter and rng.randf() < spec[6] * 0.85:
				_put(vegetation, cell, rng.randi_range(20, 23) if rng.randf() < 0.8 else 36)
			elif not path and rng.randf() < spec[6] * 0.06:
				_put(vegetation, cell, 37)
	# Authored landmarks. Every obstacle stays away from the cross-room routes.
	var rock_centers: Array[Vector2i] = []
	match spec[0]:
		"A": rock_centers = [Vector2i(11, 7), Vector2i(29, 17)]
		"B": rock_centers = [Vector2i(10, 16), Vector2i(29, 6)]
		"C": rock_centers = [Vector2i(10, 6), Vector2i(30, 17)]
		"D":
			_pool(obstacles, vegetation, walkable, blocked, Vector2(12, 7), Vector2(4.5, 2.8), rng)
			rock_centers = [Vector2i(28, 17)]
		"E":
			_pool(obstacles, vegetation, walkable, blocked, Vector2(11, 17), Vector2(2.5, 1.6), rng)
			rock_centers = [Vector2i(28, 6)]
		"F": rock_centers = [Vector2i(12, 8), Vector2i(12, 16), Vector2i(27, 8), Vector2i(27, 16)]
		"G": rock_centers = [Vector2i(8, 7), Vector2i(32, 17)]
		"H": rock_centers = [Vector2i(11, 6), Vector2i(28, 17)]
	for center in rock_centers:
		for offset in [Vector2i.ZERO, Vector2i.RIGHT, Vector2i.DOWN]:
			var cell: Vector2i = center + offset
			if walkable.has(cell):
				_put(obstacles, cell, rng.randi_range(24, 27))
				vegetation.erase_cell(cell)
				blocked.append(cell)
	# Root bundles give B its own rhythm without introducing collision hazards.
	if spec[0] in ["A", "B", "E"]:
		for y in [6, 17]:
			for x in range(14 if spec[0] == "B" else 23, 18 if spec[0] == "B" else 28):
				var cell := Vector2i(x, y)
				if walkable.has(cell) and cell not in blocked:
					_put(vegetation, cell, 28 + x % 4)
	if spec[0] == "H":
		for x in range(27, 29):
			for y in range(11, 13):
				_put(vegetation, Vector2i(x, y), 32)
	# Landmarks must not strand tiny pockets behind a pool or rock formation.
	var reachable: Dictionary = {Vector2i(20, 12): true}
	var frontier: Array[Vector2i] = [Vector2i(20, 12)]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var next: Vector2i = cell + offset
			if walkable.has(next) and next not in blocked and not reachable.has(next):
				reachable[next] = true
				frontier.append(next)
	for cell in walkable.keys():
		if not reachable.has(cell) and cell not in blocked:
			walkable.erase(cell)
			terrain.erase_cell(cell)
			vegetation.erase_cell(cell)
			_put(obstacles, cell, 8)
	var light := ColorRect.new()
	light.name = "Lighting"
	light.position = Vector2(-640, -360)
	light.size = Vector2(1280, 720)
	light.color = Color(0.9, 0.73, 0.35, 0.035) if index == 0 else Color(0.05, 0.13, 0.19, 0.03 + index * 0.012)
	light.mouse_filter = Control.MOUSE_FILTER_IGNORE
	light.z_index = -4
	_own(light, scene, scene)
	var cells: Array[Vector2i] = []
	for cell in walkable:
		cells.append(cell)
	scene.set("walkable_cells", cells)
	scene.set("blocked_cells", blocked)
	var packed := PackedScene.new()
	packed.pack(scene)
	var result := ResourceSaver.save(packed, DIR + "rooms/" + spec[2] + ".tscn")
	_make_inherited(DIR + "rooms/" + spec[2] + ".tscn")
	print("Room %s: %d walkable tiles; saved %s" % [spec[0], cells.size(), result == OK])
	scene.free()

func _pool(layer: TileMapLayer, plants: TileMapLayer, walkable: Dictionary, blocked: Array[Vector2i], center: Vector2, radius: Vector2, rng: RandomNumberGenerator) -> void:
	for y in 24:
		for x in 40:
			var cell := Vector2i(x, y)
			if not walkable.has(cell):
				continue
			var d := (Vector2(cell) - center) / radius
			if d.length_squared() < 1.0:
				_put(layer, cell, rng.randi_range(16, 19))
				plants.erase_cell(cell)
				blocked.append(cell)
			elif d.length_squared() < 1.5 and rng.randf() < 0.5:
				_put(plants, cell, 20 + rng.randi_range(0, 3))

func _make_inherited(path: String) -> void:
	var text := FileAccess.get_file_as_string(path)
	text = text.replace('[gd_scene format=4]', '[gd_scene format=4]\n\n[ext_resource type="PackedScene" path="res://shared/room_template.tscn" id="base_room"]')
	var lines := text.split("\n")
	for i in lines.size():
		var line := lines[i]
		if line.begins_with("[node ") and not line.contains("parent="):
			lines[i] = line.replace('type="Node2D"', 'instance=ExtResource("base_room")')
		elif line.begins_with('[node name="EntryPoint"'):
			lines[i] = line.replace('type="Marker2D"', 'index="0"')
		elif line.begins_with('[node name="Doorways"'):
			lines[i] = line.replace('type="Node2D"', 'index="1"')
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(lines))
