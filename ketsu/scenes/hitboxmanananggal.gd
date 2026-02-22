extends Area2D

func _ready():
	add_to_group("enemy_hurtbox")

func take_damage(amount: int, from_position: Vector2):
	var boss = get_parent()
	if boss and boss.has_method("take_damage"):
		boss.take_damage(amount, from_position)
