extends DungeonFloor

const STARTER_ROOM: PackedScene = preload("res://floors/floor_2/rooms/starter.tscn")
const BOSS_ROOM: PackedScene = preload("res://floors/floor_2/rooms/boss.tscn")
const GALLERY_ROOM: PackedScene = preload("res://floors/floor_2/rooms/gallery.tscn")
const SHRINE_ROOM: PackedScene = preload("res://floors/floor_2/rooms/shrine.tscn")
const STAIRS_ROOM: PackedScene = preload("res://floors/floor_2/rooms/stairs.tscn")
const STARTER_ORIGIN := Vector2.ZERO
const DEMO_MOVE_SPEED := 900.0

func _ready() -> void:
	call_deferred("_enable_demo_speed")
	var starter := add_room(STARTER_ROOM, &"StarterRoom", STARTER_ORIGIN)
	var boss := add_room(BOSS_ROOM, &"BossRoom", Vector2.ZERO)
	var gallery := add_room(GALLERY_ROOM, &"GalleryRoom", Vector2.ZERO)
	var shrine := add_room(SHRINE_ROOM, &"ShrineRoom", Vector2.ZERO)
	var stairs := add_room(STAIRS_ROOM, &"StairsRoom", Vector2.ZERO)
	var side_cave := add_room(STAIRS_ROOM, &"SideCave", Vector2.ZERO)
	_randomize_layout([starter, boss, gallery, shrine, stairs, side_cave])
	_sync_floor_entry_to_starter(starter)
	connect_rooms(starter, &"East", boss, &"West")
	connect_rooms(boss, &"North", gallery, &"South")
	connect_rooms(gallery, &"East", shrine, &"West")
	connect_rooms(shrine, &"South", stairs, &"North")
	connect_rooms(gallery, &"North", side_cave, &"North")
	_add_stairs_visuals(stairs)
	_add_next_floor_trigger(stairs, 3)
	build_live_minimap(
		[starter, boss, gallery, shrine, stairs, side_cave],
		[
			[starter, &"East", boss, &"West"], [boss, &"North", gallery, &"South"],
			[gallery, &"East", shrine, &"West"], [shrine, &"South", stairs, &"North"],
			[gallery, &"North", side_cave, &"North"]
		],
		Color("#050507ed"), Color("#e5e5ef")
	)

func _randomize_layout(layout_rooms: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.randomize()
	var quarter_turn := random.randi_range(0, 3)
	for room_node in layout_rooms:
		var room := room_node as DungeonRoom
		if room == null:
			continue
		room.rotation = quarter_turn * PI * 0.5
		room.scale = Vector2.ONE
	var starter := layout_rooms[0] as DungeonRoom
	var boss := layout_rooms[1] as DungeonRoom
	var gallery := layout_rooms[2] as DungeonRoom
	var shrine := layout_rooms[3] as DungeonRoom
	var stairs := layout_rooms[4] as DungeonRoom
	var side_cave := layout_rooms[5] as DungeonRoom
	side_cave.rotation = quarter_turn * PI * 0.5 + PI
	starter.position = Vector2.ZERO
	place_room_at_exit(starter, &"East", boss, &"West", random_grid_distance(random, 500.0, 760.0))
	place_room_at_exit(boss, &"North", gallery, &"South", random_grid_distance(random, 480.0, 720.0))
	place_room_at_exit(gallery, &"East", shrine, &"West", random_grid_distance(random, 480.0, 740.0))
	place_room_at_exit(shrine, &"South", stairs, &"North", random_grid_distance(random, 480.0, 720.0))
	place_room_at_exit(gallery, &"North", side_cave, &"North", random_grid_distance(random, 480.0, 700.0))

func _process(_delta: float) -> void:
	super(_delta)

func _sync_floor_entry_to_starter(starter: DungeonRoom) -> void:
	if starter == null:
		return
	var floor_entry := get_node_or_null(entry_marker_path) as Marker2D
	var starter_entry := starter.get_node_or_null("EntryPoint") as Marker2D
	if floor_entry != null and starter_entry != null:
		floor_entry.global_position = starter_entry.global_position

func _enable_demo_speed() -> void:
	var player := get_tree().get_first_node_in_group("player") as TemporaryDungeonPlayer
	if player != null:
		player.move_speed = DEMO_MOVE_SPEED

func _add_stairs_visuals(stairs_room: DungeonRoom) -> void:
	for step_index in range(6):
		var step := ColorRect.new()
		step.name = "StairStep_%d" % step_index
		step.position = Vector2(-450.0 + step_index * 90.0, 270.0 - step_index * 90.0)
		step.size = Vector2(900.0 - step_index * 120.0, 72.0)
		step.color = Color("#101014") if step_index % 2 == 0 else Color("#e9e9ef")
		stairs_room.add_child(step)

func _add_next_floor_trigger(stairs_room: DungeonRoom, floor_number: int) -> void:
	var trigger := Area2D.new()
	trigger.name = "NextFloorTrigger"
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(960.0, 720.0)
	collision.shape = shape
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_next_floor_body_entered.bind(floor_number))
	stairs_room.add_child(trigger)

func _on_next_floor_body_entered(body: Node2D, floor_number: int) -> void:
	if body.is_in_group("player"):
		next_floor_requested.emit(floor_number)
