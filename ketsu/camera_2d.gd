extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_decay: float = 10.0
@export var look_ahead_distance := 90.0
@export var look_ahead_speed := 6
@export var follow_speed := 1
@export var target: Node2D
# For room transitions



# --- SCREEN SHAKE ---
func apply_shake(intensity: float = 20.0, duration: float = 0.2):
	shake_intensity = intensity
	shake_duration = duration


func _process(delta):
	var player := get_parent()
	if player == null:
		return

	# --- FOLLOW TARGET ---
	if target:
		global_position = global_position.lerp(
			target.global_position,
			delta * follow_speed
		)

	# --- LOOK AHEAD ---
	var dir: Vector2 = player.last_move_dir.normalized()
	if dir.length() < 0.1:
		dir = Vector2.ZERO

	var target_offset = dir * look_ahead_distance
	position = position.lerp(target_offset, delta * look_ahead_speed)

	# --- SCREEN SHAKE ---
	var shake_offset := Vector2.ZERO

	if shake_duration > 0.0:
		shake_duration -= delta

		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

		shake_intensity = lerp(
			shake_intensity,
			0.0,
			delta * shake_decay
		)

	# ✅ APPLY SHAKE ON TOP OF CURRENT OFFSET
	position += shake_offset
