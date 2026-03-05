extends Camera2D

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_decay: float = 10.0  # higher = stops faster

func apply_shake(intensity: float = 5.0, duration: float = 0.2):
	shake_intensity = intensity
	shake_duration = duration
	print("[Camera] Shake applied: intensity =", intensity, "duration =", duration)
	
func _process(delta):
	if shake_duration > 0:
		shake_duration -= delta
		offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)
		shake_intensity = lerp(shake_intensity, 0.0, delta * shake_decay)
	else:
		offset = Vector2.ZERO
