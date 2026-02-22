extends StaticBody2D

func _on_playerdetector_body_entered(body: Node2D) -> void:
	collision_layer = 1
	print("playerentered")
