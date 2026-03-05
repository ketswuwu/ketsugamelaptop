extends StaticBody2D
@onready var gate: AnimatedSprite2D = $AnimatedSprite2D
func _on_playerdetector_body_entered(body: Node2D) -> void:
	collision_layer = 1
	print("playerentered")
	gate.play("gate_up")
