extends Area2D

func take_damage(amount: int, from_position: Vector2):
	var enemy = get_parent()
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(amount, from_position)
