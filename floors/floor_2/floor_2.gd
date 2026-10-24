extends DungeonFloor

const STARTER_ROOM: PackedScene = preload("res://floors/floor_2/rooms/starter.tscn")
const BOSS_ROOM: PackedScene = preload("res://floors/floor_2/rooms/boss.tscn")
const STAIRS_ROOM: PackedScene = preload("res://floors/floor_2/rooms/stairs.tscn")
const STARTER_ORIGIN := Vector2.ZERO
const BOSS_ORIGIN := Vector2(1280.0, 0.0)
const STAIRS_ORIGIN := Vector2(2560.0, 0.0)

func _ready() -> void:
	var starter := add_room(STARTER_ROOM, &"StarterRoom", STARTER_ORIGIN)
	var boss := add_room(BOSS_ROOM, &"BossRoomPlaceholder", BOSS_ORIGIN)
	var stairs := add_room(STAIRS_ROOM, &"StairsRoom", STAIRS_ORIGIN)
	connect_rooms(starter, &"East", boss, &"West")
	connect_rooms(boss, &"East", stairs, &"West")
	_add_stairs_visuals(STAIRS_ORIGIN)
	_add_next_floor_trigger(STAIRS_ORIGIN, 3)

func _add_stairs_visuals(origin: Vector2) -> void:
	for step_index in range(6):
		var step := ColorRect.new()
		step.name = "StairStep_%d" % step_index
		step.position = origin + Vector2(-150.0 + step_index * 30.0, 90.0 - step_index * 30.0)
		step.size = Vector2(300.0 - step_index * 40.0, 24.0)
		step.color = Color("#92704d") if step_index % 2 == 0 else Color("#b8875b")
		add_child(step)

func _add_next_floor_trigger(origin: Vector2, floor_number: int) -> void:
	var trigger := Area2D.new()
	trigger.name = "NextFloorTrigger"
	trigger.position = origin
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(320.0, 240.0)
	collision.shape = shape
	trigger.add_child(collision)
	trigger.body_entered.connect(_on_next_floor_body_entered.bind(floor_number))
	add_child(trigger)

func _on_next_floor_body_entered(body: Node2D, floor_number: int) -> void:
	if body.is_in_group("player"):
		next_floor_requested.emit(floor_number)
