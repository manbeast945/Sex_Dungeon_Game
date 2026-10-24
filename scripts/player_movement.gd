class_name TemporaryDungeonPlayer
extends CharacterBody2D

@export var move_speed := 220.0
var movement_enabled := true

const BODY_COLOR := Color("#d9a654")
const TRIM_COLOR := Color("#653f31")

func _ready() -> void:
	queue_redraw()

func _physics_process(_delta: float) -> void:
	if not movement_enabled:
		velocity = Vector2.ZERO
		return
	var input_vector := Vector2.ZERO
	input_vector.x = float(Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT))
	input_vector.y = float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP))
	velocity = input_vector.normalized() * move_speed
	move_and_slide()

func set_movement_enabled(enabled: bool) -> void:
	movement_enabled = enabled
	if not enabled:
		velocity = Vector2.ZERO

func _draw() -> void:
	draw_rect(Rect2(-10.0, -15.0, 20.0, 30.0), BODY_COLOR)
	draw_rect(Rect2(-10.0, 9.0, 20.0, 6.0), TRIM_COLOR)
	draw_rect(Rect2(-5.0, -8.0, 3.0, 3.0), Color("#2d2522"))
	draw_rect(Rect2(2.0, -8.0, 3.0, 3.0), Color("#2d2522"))

