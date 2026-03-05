# bullet.gd (Area2D)
extends Area2D

@export var speed := 1200.0
@export var life_time := 2.0
@export var damage := 10

var velocity := Vector2.ZERO

func setup(dir: Vector2, spd: float = -1.0) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	velocity = dir.normalized() * (spd if spd > 0.0 else speed)
	rotation = velocity.angle()

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

	await get_tree().create_timer(life_time).timeout
	queue_free()

func _physics_process(delta: float) -> void:
	global_position += velocity * delta

func _deal_damage_to(target: Node) -> void:
	if not is_instance_valid(target):
		return

	# Common patterns:
	# 1) Enemy has take_damage(dmg, from_position)
	if target.has_method("take_damage"):
		target.take_damage(damage, global_position)
		queue_free()
		return

	# 2) Sometimes the collider is a Hurtbox Area2D child
	#    so we try its parent as well
	var p := target.get_parent()
	if is_instance_valid(p) and p.has_method("take_damage"):
		p.take_damage(damage, global_position)
		queue_free()
		return

func _on_body_entered(body: Node) -> void:
	# Example: only damage enemies
	if body.is_in_group("enemy") or body.is_in_group("boss") or body.is_in_group("enemies"):
		_deal_damage_to(body)

func _on_area_entered(area: Area2D) -> void:
	# If you use enemy hurtboxes (recommended), detect those
	if area.is_in_group("enemy_hurtbox"):
		_deal_damage_to(area)
