extends SceneTree
## Checks startup, all directed edges, collisions, cache, and teammate floors.
var failures := 0
var checks := 0
var floor_one_intros := 0
var manager: Node

func _initialize() -> void:
	create_timer(55).timeout.connect(_timeout)
	call_deferred("_run")

func _timeout() -> void:
	push_error("Regression test timed out")
	quit(1)

func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func _settle(seconds := 0.85) -> void:
	await create_timer(seconds).timeout
	await physics_frame
	await physics_frame

func _unlock() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_1
	key.pressed = true
	manager._unhandled_key_input(key)
	await physics_frame
	await physics_frame

func _solid(point: Vector2) -> bool:
	var query := PhysicsPointQueryParameters2D.new()
	query.position = point
	query.collision_mask = 1
	query.exclude = [manager.player.get_rid()]
	return not manager.player.get_world_2d().direct_space_state.intersect_point(query).is_empty()

func _run() -> void:
	manager = load("res://scenes/main.tscn").instantiate()
	root.add_child(manager)
	manager.floor_transition_label.visibility_changed.connect(func():
		if manager.floor_transition_label.visible and manager.floor_transition_label.text == "Floor 1":
			floor_one_intros += 1
	)
	await _settle(0.05)
	_check(manager.current_area_id == &"entrance", "Startup must be outside Floor 1")
	_check(manager.current_floor.rooms.size() == 1, "Plain entrance has one room")
	_check(manager.current_floor.rooms[&"EntranceRoom"].generate_rectangular_shell, "Entrance should be the original plain shell")
	_check(manager.player.position.is_equal_approx(Vector2.ZERO), "Startup spawn is centered")
	_check(not manager.floor_transition_label.visible and not manager.floor_one_seen, "Do not show Floor 1 on startup")
	# Walk through the entrance instead of calling the transition directly.
	manager.player.position = Vector2(480, 0)
	var press := InputEventKey.new()
	press.keycode = KEY_D
	press.pressed = true
	Input.parse_input_event(press)
	await _settle(0.4)
	var release := InputEventKey.new()
	release.keycode = KEY_D
	release.pressed = false
	Input.parse_input_event(release)
	await _settle(1.25)
	_check(manager.current_area_id == &"floor_1", "Walking east must enter Floor 1")
	_check(manager.floor_one_seen, "First dungeon entry records the Floor 1 intro")
	_check(not manager.doors_locked, "Floor 1 starts freely explorable")
	var floor_one: DungeonFloor = manager.current_floor
	_check(floor_one.rooms.size() == 8, "Floor 1 must contain exactly eight rooms")
	_check(floor_one.room_doorways.size() == 16, "Eight links must have sixteen directional triggers")
	for id in floor_one.rooms:
		var room: DungeonRoom = floor_one.rooms[id]
		var open: Dictionary = {}
		for cell in room.walkable_cells:
			if cell not in room.blocked_cells:
				open[cell] = true
		var visited: Dictionary = {Vector2i(20, 12): true}
		var queue: Array[Vector2i] = [Vector2i(20, 12)]
		while not queue.is_empty():
			var current := queue.pop_back() as Vector2i
			for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = current + offset
				if open.has(next) and not visited.has(next):
					visited[next] = true
					queue.append(next)
		_check(visited.size() == open.size(), "%s: all walkable tiles must be reachable" % id)
		for cell in room.blocked_cells:
			var at := room.position + Vector2(-640, -384) + (Vector2(cell) + Vector2(0.5, 0.5)) * 32
			_check(_solid(at), "%s: water/boulder collision at %s" % [id, cell])
		# Each solid wall tile must collide; every open tile center stays clear.
		for y in range(1, 23):
			for x in range(1, 39):
				var cell := Vector2i(x, y)
				var at := room.position + Vector2(-640, -384) + (Vector2(cell) + Vector2(0.5, 0.5)) * 32
				_check(_solid(at) == not open.has(cell), "%s: collision matches tile %s" % [id, cell])
		for doorway in room.get_node("Doorways").get_children():
			var arrival: Vector2 = room.get_arrival_position(doorway.name)
			_check(not manager.player.test_move(Transform2D(0.0, room.position), arrival - room.position), "%s/%s: central walking route stays clear" % [id, doorway.name])
	print("CHECKED: eight reachable room interiors, tile collision, water, boulders, clear doorway routes")
	# Visit every reciprocal connection through its physics trigger.
	for edge in floor_one.CONNECTIONS:
		for reverse in [false, true]:
			var source: DungeonRoom = floor_one.rooms[edge[2] if reverse else edge[0]]
			var dest: DungeonRoom = floor_one.rooms[edge[0] if reverse else edge[2]]
			var exit_id: StringName = edge[3] if reverse else edge[1]
			var arrival_id: StringName = edge[1] if reverse else edge[3]
			manager.player.position = source.position
			manager.camera.position = source.position
			await _settle(0.04)
			var marker := source.get_doorway_marker(exit_id)
			manager.player.position = marker.global_position - marker.global_transform.x.normalized() * 42
			await _settle()
			_check(manager.camera.position.is_equal_approx(dest.position), "Directed edge %s/%s reaches %s" % [source.name, exit_id, dest.name])
			_check(manager.player.position.is_equal_approx(dest.get_arrival_position(arrival_id)), "Arrival matches the opposite marker")
			_check(not manager.doors_locked and not manager.transition_running, "Free travel requires no unlock and must not retrigger")
	print("CHECKED: all sixteen directional room connections, including loop and side branch")
	floor_one.set_meta("persistent_visit", 42)
	manager.player.position = Vector2.ZERO
	await _settle(0.04)
	manager.player.position = Vector2(-580, 0)
	await _settle()
	_check(manager.current_area_id == &"entrance", "West exit returns to plain entrance")
	_check(manager.player.position.is_equal_approx(Vector2(460, 0)), "Entrance return clears its trigger")
	_check(not floor_one.visible and floor_one.process_mode == Node.PROCESS_MODE_DISABLED, "Inactive Floor 1 is hidden and disabled")
	manager.player.position = Vector2(580, 0)
	await _settle()
	_check(floor_one_intros == 1, "Floor 1 title appears only on first dungeon entry")
	_check(manager.current_floor == floor_one and floor_one.get_meta("persistent_visit") == 42, "Re-entry preserves the exact Floor 1 instance")
	_check(not manager.floor_transition_label.visible, "Repeated entry completes without a repeated intro")
	# The descent trigger must not overlap arrival, and must work on walking up.
	var h: DungeonRoom = floor_one.rooms[&"H"]
	manager.player.position = h.get_arrival_position(&"West")
	manager.camera.position = h.position
	await _settle(0.1)
	_check(manager.current_area_id == &"floor_1", "H's western arrival must not trigger stairs")
	manager.player.position = h.position + Vector2(256, 0)
	await _settle(1.5)
	_check(manager.current_area_id == &"floor_2", "H stairs reach Floor 2")
	_check(manager.doors_locked and not manager.current_floor.free_exploration, "Floor 2 retains manual door locks")
	await _unlock()
	manager.player.position = Vector2(580, 0)
	await _settle()
	_check(manager.camera.position.is_equal_approx(Vector2(1280, 0)) and manager.doors_locked, "Floor 2 room travel retains lock behavior")
	await _unlock()
	manager.player.position = Vector2(1860, 0)
	await _settle()
	await _unlock()
	# Preserve the teammates' existing stairs behavior, including trigger re-entry.
	manager.player.position = Vector2(2920, 0)
	await _settle(0.08)
	manager.player.position = Vector2(2560, 0)
	await _settle(1.5)
	_check(manager.current_area_id == &"floor_3" and manager.doors_locked, "Floor 3 progression and locks remain operational")
	print("CHECKED: separate entrance, cached return, stairs and teammates' floor behavior")
	print("RESULT: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
