extends Area2D

@export var speed: float = 700.0
@export var life_time: float = 3.0
@export var damage: int = 1

var direction: Vector2 = Vector2.RIGHT

func setup(dir: Vector2, dmg: int) -> void:
	direction = dir
	damage = dmg

func _ready() -> void:
	monitoring = true
	monitorable = true
	body_entered.connect(_on_body_entered)

	# Auto-despawn
	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta

func _on_body_entered(body: Node) -> void:
	# Hit player
	if body.is_in_group("player"):
		if body.has_method("take_damage"):
			body.take_damage(damage, global_position)
		queue_free()
		return

	# Hit walls / world (choose ONE approach below)

	# Approach A: group-based (recommended)
	if body.is_in_group("world"):
		queue_free()
		return

	# Approach B: type-based (useful if you don't want groups)
	# if body is StaticBody2D or body is TileMap:
	# 	queue_free()
	# 	return
