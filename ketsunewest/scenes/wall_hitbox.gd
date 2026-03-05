extends Area2D

@export var max_health := 15
@export var shake_strength := 12.0
@export var shake_duration := 0.12

var current_health := 0
var original_position: Vector2
var is_shaking := false

func _ready():
	current_health = max_health
	original_position = position
	add_to_group("breakable")

func take_damage(amount: int) -> void:
	current_health -= amount
	shake()

	if current_health <= 0:
		break_wall()

func shake():
	if is_shaking:
		return

	is_shaking = true
	var elapsed := 0.0

	while elapsed < shake_duration:
		var offset = Vector2(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		) * shake_strength

		position = original_position + offset
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	position = original_position
	is_shaking = false

func break_wall():
	State.wall_status = "broken"
	queue_free()
