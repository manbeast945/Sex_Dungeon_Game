extends DungeonFloor
## Intentionally plain staging area. This is not one of Floor 1's eight rooms.
const ROOM := preload("res://floors/floor_1/rooms/entrance_room.tscn")

func _ready() -> void:
	add_room(ROOM, &"EntranceRoom", Vector2.ZERO)
	var passage := Area2D.new()
	passage.name = "EnterDungeon"
	passage.position = Vector2(580, 0)
	var collision := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(88, 128)
	collision.shape = shape
	passage.add_child(collision)
	passage.body_entered.connect(_on_passage_entered)
	add_child(passage)

func _on_passage_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		area_transition_requested.emit(&"floor_1")
