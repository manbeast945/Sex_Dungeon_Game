class_name DungeonFloor
extends Node2D

signal room_transition_requested(player_position: Vector2, camera_position: Vector2)
signal next_floor_requested(floor_number: int)
signal area_transition_requested(area_id: StringName)

@export var entry_marker_path: NodePath = ^"EntryPoint"
## Opt in per area. Existing teammates' floors retain manual door unlocking.
@export var free_exploration := false

var room_doorways: Array[Area2D] = []
var room_door_barriers: Array[CollisionShape2D] = []
var rooms: Dictionary = {}

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
	_add_room_doorway(room_a, marker_a, room_b, room_b.get_arrival_position(exit_b))
	_add_room_doorway(room_b, marker_b, room_a, room_a.get_arrival_position(exit_a))

func set_room_doors_enabled(enabled: bool) -> void:
	for doorway in room_doorways:
		if is_instance_valid(doorway):
			doorway.set_deferred("monitoring", enabled)
	for barrier in room_door_barriers:
		if is_instance_valid(barrier):
			barrier.set_deferred("disabled", enabled)

func _add_room_doorway(source_room: DungeonRoom, marker: Marker2D, destination_room: DungeonRoom, destination_position: Vector2) -> void:
	var outward := marker.global_transform.x.normalized()
	if outward.is_zero_approx():
		outward = Vector2.RIGHT
	var doorway := Area2D.new()
	doorway.name = "Door_%s_%s" % [source_room.name, marker.name]
	doorway.position = to_local(marker.global_position - outward * 42.0)
	doorway.rotation = marker.global_rotation
	var trigger_collision := CollisionShape2D.new()
	var trigger_shape := RectangleShape2D.new()
	trigger_shape.size = Vector2(88.0, source_room.door_gap)
	trigger_collision.shape = trigger_shape
	doorway.add_child(trigger_collision)
	doorway.body_entered.connect(_on_room_doorway_entered.bind(destination_position, destination_room.get_camera_position()))
	room_doorways.append(doorway)
	add_child(doorway)

	var barrier := StaticBody2D.new()
	barrier.name = "LockedDoorBarrier_%s_%s" % [source_room.name, marker.name]
	barrier.position = to_local(marker.global_position)
	barrier.rotation = marker.global_rotation
	barrier.collision_layer = 1
	barrier.collision_mask = 0
	var barrier_collision := CollisionShape2D.new()
	var barrier_shape := RectangleShape2D.new()
	barrier_shape.size = Vector2(source_room.wall_thickness, source_room.door_gap)
	barrier_collision.shape = barrier_shape
	barrier.add_child(barrier_collision)
	room_door_barriers.append(barrier_collision)
	add_child(barrier)

func _on_room_doorway_entered(body: Node2D, destination_position: Vector2, destination_camera: Vector2) -> void:
	if not body.is_in_group("player"):
		return
	room_transition_requested.emit(destination_position, destination_camera)
