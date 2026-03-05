extends Area2D

@export var owner_enemy: NodePath

func _ready() -> void:
	# Put hurtboxes in a dedicated group so the player's melee hitbox can target only these.
	add_to_group("enemy_hurtbox")

func take_damage(amount: int, from_position: Vector2) -> void:
	var enemy: Node = get_node_or_null(owner_enemy)
	if enemy == null:
		enemy = get_parent() # fallback if you didn't set owner_enemy

	if enemy and enemy.has_method("take_damage"):
		enemy.call("take_damage", amount, from_position)
