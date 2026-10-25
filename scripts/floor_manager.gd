extends Node2D

const FLOOR_SCENES: Array[PackedScene] = [
	preload("res://floors/floor_1/floor_1.tscn"),
	preload("res://floors/floor_2/floor_2.tscn"),
	preload("res://floors/floor_3/floor_3.tscn"),
]
const PLAYER_SCENE: PackedScene = preload("res://scenes/player.tscn")
const TRANSITION_SECONDS := 0.38
const MAX_HEALTH := 100

var current_floor: DungeonFloor
var player: TemporaryDungeonPlayer
var camera: Camera2D
var transition_running := false
var doors_locked := false
var iris_material: ShaderMaterial
var floor_transition_label: Label
var player_health := MAX_HEALTH
var coin_count := 0
var health_fill: ColorRect
var health_value_label: Label
var coin_value_label: Label

func _ready() -> void:
	_build_player()
	_build_camera()
	_build_iris()
	_build_hud()
	_load_initial_floor()

func _build_player() -> void:
	player = PLAYER_SCENE.instantiate() as TemporaryDungeonPlayer
	player.add_to_group("player")
	add_child(player)

func _build_camera() -> void:
	camera = Camera2D.new()
	camera.name = "RoomCamera"
	camera.enabled = true
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.5
	camera.drag_horizontal_enabled = true
	camera.drag_vertical_enabled = true
	camera.drag_left_margin = 0.18
	camera.drag_right_margin = 0.18
	camera.drag_top_margin = 0.18
	camera.drag_bottom_margin = 0.18
	player.add_child(camera)
	camera.make_current()

func _build_iris() -> void:
	var overlay := ColorRect.new()
	overlay.name = "IrisTransition"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := load("res://scripts/iris_transition.gdshader") as Shader
	iris_material = ShaderMaterial.new()
	iris_material.shader = shader
	iris_material.set_shader_parameter("radius", 2.0)
	overlay.material = iris_material
	floor_transition_label = Label.new()
	floor_transition_label.name = "FloorTransitionLabel"
	floor_transition_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	floor_transition_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	floor_transition_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	floor_transition_label.add_theme_color_override("font_color", Color.WHITE)
	floor_transition_label.add_theme_font_size_override("font_size", 52)
	floor_transition_label.visible = false
	overlay.add_child(floor_transition_label)
	var canvas := CanvasLayer.new()
	canvas.name = "TransitionLayer"
	canvas.layer = 10
	canvas.add_child(overlay)
	add_child(canvas)

func _build_hud() -> void:
	var hud := CanvasLayer.new()
	hud.name = "GameHUD"
	hud.layer = 6
	add_child(hud)

	var health_panel := _make_panel(Vector2(24.0, 24.0), Vector2(272.0, 78.0))
	hud.add_child(health_panel)
	var health_title := _make_label("HEALTH", Vector2(14.0, 10.0), Vector2(100.0, 20.0), 15, Color("#f1d8d3"))
	health_panel.add_child(health_title)
	health_value_label = _make_label("100 / 100", Vector2(162.0, 10.0), Vector2(96.0, 20.0), 15, Color("#ffffff"), HORIZONTAL_ALIGNMENT_RIGHT)
	health_panel.add_child(health_value_label)
	var health_track := ColorRect.new()
	health_track.position = Vector2(14.0, 39.0)
	health_track.size = Vector2(244.0, 22.0)
	health_track.color = Color("#321d28")
	health_panel.add_child(health_track)
	health_fill = ColorRect.new()
	health_fill.position = Vector2(3.0, 3.0)
	health_fill.color = Color("#db4a5a")
	health_track.add_child(health_fill)

	var coins_panel := _make_panel(Vector2(24.0, 114.0), Vector2(176.0, 46.0))
	hud.add_child(coins_panel)
	var coins_title := _make_label("COINS", Vector2(14.0, 12.0), Vector2(76.0, 20.0), 15, Color("#f5d476"))
	coins_panel.add_child(coins_title)
	coin_value_label = _make_label("0", Vector2(101.0, 9.0), Vector2(60.0, 24.0), 20, Color("#fff3c4"), HORIZONTAL_ALIGNMENT_RIGHT)
	coins_panel.add_child(coin_value_label)

	var inventory_panel := _make_panel(Vector2.ZERO, Vector2(532.0, 82.0))
	inventory_panel.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	inventory_panel.position = Vector2(-266.0, -106.0)
	hud.add_child(inventory_panel)
	var inventory_title := _make_label("INVENTORY", Vector2(14.0, 8.0), Vector2(120.0, 16.0), 13, Color("#c9d3df"))
	inventory_panel.add_child(inventory_title)
	for slot_index in range(6):
		var slot := ColorRect.new()
		slot.position = Vector2(142.0 + slot_index * 61.0, 10.0)
		slot.size = Vector2(51.0, 62.0)
		slot.color = Color("#28313b")
		inventory_panel.add_child(slot)
		var hotkey := _make_label(str(slot_index + 1), Vector2(5.0, 4.0), Vector2(16.0, 16.0), 12, Color("#91a0af"))
		slot.add_child(hotkey)
		var empty_marker := _make_label("—", Vector2(0.0, 18.0), Vector2(51.0, 28.0), 20, Color("#5d6976"), HORIZONTAL_ALIGNMENT_CENTER)
		slot.add_child(empty_marker)
	_refresh_hud()

func _make_panel(panel_position: Vector2, panel_size: Vector2) -> ColorRect:
	var panel := ColorRect.new()
	panel.position = panel_position
	panel.size = panel_size
	panel.color = Color("#10151ddd")
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _make_label(label_text: String, label_position: Vector2, label_size: Vector2, font_size: int, font_color: Color, alignment := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = label_text
	label.position = label_position
	label.size = label_size
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	label.horizontal_alignment = alignment
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label

func set_player_health(value: int) -> void:
	player_health = clampi(value, 0, MAX_HEALTH)
	_refresh_hud()

func add_coins(amount: int) -> void:
	coin_count = maxi(0, coin_count + amount)
	_refresh_hud()

func damage_player(amount: int) -> void:
	set_player_health(player_health - maxi(0, amount))

func _refresh_hud() -> void:
	if health_fill != null:
		health_fill.size = Vector2(238.0 * float(player_health) / float(MAX_HEALTH), 16.0)
	if health_value_label != null:
		health_value_label.text = "%d / %d" % [player_health, MAX_HEALTH]
	if coin_value_label != null:
		coin_value_label.text = str(coin_count)

func _load_initial_floor() -> void:
	current_floor = FLOOR_SCENES[0].instantiate() as DungeonFloor
	_connect_floor_signals(current_floor)
	add_child(current_floor)
	player.global_position = current_floor.get_entry_position()
	camera.global_position = current_floor.get_entry_position()
	camera.reset_smoothing()
	current_floor.set_room_doors_enabled(true)
	doors_locked = false

func _connect_floor_signals(floor: DungeonFloor) -> void:
	floor.room_transition_requested.connect(_on_room_transition_requested)
	floor.next_floor_requested.connect(_on_next_floor_requested)

func _on_room_transition_requested(player_position: Vector2, camera_position: Vector2) -> void:
	if transition_running or doors_locked:
		return
	_transition_within_floor(player_position, camera_position)

func _transition_within_floor(player_position: Vector2, camera_position: Vector2) -> void:
	transition_running = true
	_lock_current_floor_doors()
	player.set_movement_enabled(false)
	player.velocity = Vector2.ZERO
	await _animate_iris(0.0)
	player.global_position = player_position
	player.velocity = Vector2.ZERO
	camera.global_position = camera_position
	camera.reset_smoothing()
	await _animate_iris(2.0)
	player.set_movement_enabled(true)
	doors_locked = false
	transition_running = false

func _on_next_floor_requested(floor_number: int) -> void:
	if transition_running or floor_number < 1 or floor_number > FLOOR_SCENES.size():
		return
	_transition_to_floor(FLOOR_SCENES[floor_number - 1], "Floor %d" % floor_number)

func _transition_to_floor(next_floor_scene: PackedScene, floor_name: String) -> void:
	transition_running = true
	_lock_current_floor_doors()
	player.set_movement_enabled(false)
	player.velocity = Vector2.ZERO
	await _animate_iris(0.0)
	floor_transition_label.text = floor_name
	floor_transition_label.visible = true
	await get_tree().create_timer(0.65).timeout
	current_floor.queue_free()
	current_floor = next_floor_scene.instantiate() as DungeonFloor
	_connect_floor_signals(current_floor)
	add_child(current_floor)
	player.global_position = current_floor.get_entry_position()
	player.velocity = Vector2.ZERO
	camera.global_position = current_floor.get_entry_position()
	camera.reset_smoothing()
	current_floor.set_room_doors_enabled(true)
	floor_transition_label.visible = false
	await _animate_iris(2.0)
	player.set_movement_enabled(true)
	doors_locked = false
	transition_running = false

func _lock_current_floor_doors() -> void:
	doors_locked = true
	if current_floor != null:
		current_floor.set_room_doors_enabled(false)

func _unhandled_key_input(event: InputEvent) -> void:
	if not doors_locked or transition_running or not event is InputEventKey:
		return
	var key_event := event as InputEventKey
	if key_event.pressed and not key_event.echo and key_event.keycode == KEY_1:
		doors_locked = false
		if current_floor != null:
			current_floor.set_room_doors_enabled(true)

func _animate_iris(target_radius: float) -> void:
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_method(_set_iris_radius, float(iris_material.get_shader_parameter("radius")), target_radius, TRANSITION_SECONDS)
	await tween.finished

func _set_iris_radius(value: float) -> void:
	iris_material.set_shader_parameter("radius", value)
