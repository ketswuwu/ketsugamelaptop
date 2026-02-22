extends CharacterBody2D

@export var max_health: int = 35
@export var damage: int = 1
@export var damage_cooldown: float = 0.5

var can_damage: bool = true
var player_in_range: Node = null
var current_health: int
var is_hurt: bool = false

@onready var hitbox: Area2D = $Area2D
@onready var damage_timer: Timer = $DamageTimer
@onready var sprite: Sprite2D = $Sprite2D

@export var move_speed := 200
@export var knockback_force: float = 300.0
@export var knockback_duration: float = 0.05
var knockback_vector: Vector2 = Vector2.ZERO
var is_knocked_back: bool = false

var target: Node2D = null
var is_chasing := false
var is_alerted := false
var alert_duration := 0.3

@onready var detection_area: Area2D = $DetectionArea

@onready var wander_timer: Timer = $WandererTimer

@export var wander_speed := 80.0
@export var wander_change_time := 2.0

var wander_direction: Vector2 = Vector2.ZERO

func _ready():
	current_health = max_health
	wander_timer.timeout.connect(_pick_new_wander_direction)
	_pick_new_wander_direction()
	hitbox.body_entered.connect(_on_body_entered)
	hitbox.body_exited.connect(_on_body_exited)
	damage_timer.connect("timeout", Callable(self, "_on_DamageTimer_timeout"))
	detection_area.body_entered.connect(_on_detection_entered)
	detection_area.body_exited.connect(_on_detection_exited)
	
	# 🩸 Called by player when hit
func _on_detection_entered(body):
	if body.is_in_group("player"):
		print("[Enemy] Player detected!")
		target = body
		_start_alert()	

func _pick_new_wander_direction():
	wander_direction = Vector2(
		randf_range(-1.0, 1.0),
		randf_range(-1.0, 1.0)
	)

	# Prevent zero-length vector
	if wander_direction.length() < 0.1:
		wander_direction = Vector2.RIGHT

	wander_direction = wander_direction.normalized()

	# Occasionally stop instead of moving
	if randf() < 0.3:
		wander_direction = Vector2.ZERO
		
func _start_alert():
	is_alerted = true
	is_chasing = false
	velocity = Vector2.ZERO

	# ▶ Play notice animation here
	if $AnimationPlayer:
		$AnimationPlayer.play("notice")

	await get_tree().create_timer(alert_duration).timeout

	# Player might have left during alert
	if target:
		is_chasing = true
		Combatmusicmanager.enemy_started_combat()

	is_alerted = false
func _on_detection_exited(body):
	if body == target:
		target = null
		stop_combat()
func take_damage(amount: int, source_position: Vector2 = global_position):
	if is_hurt:
		return

	is_hurt = true
	can_damage = false             
	hitbox.monitoring = false      

	current_health -= amount
	print("[Enemy] Took damage:", amount, "remaining:", current_health)

	# Flash red
	sprite.modulate = Color(1, 0.3, 0.3)
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color(1, 1, 1)

	# Knockback
	var direction = (global_position - source_position).normalized()
	knockback_vector = direction * knockback_force
	is_knocked_back = true

	# Recover from hurt
	await get_tree().create_timer(0.25).timeout
	is_hurt = false
	hitbox.monitoring = true      
	can_damage = true                

	if current_health <= 0:
		die()
func die():
	print("[Enemy] Died!")

	if is_chasing:
		Combatmusicmanager.enemy_stopped_combat()

	is_chasing = false
	is_hurt = false

	if has_node("Area2D/CollisionShape2D"):
		$Area2D/CollisionShape2D.disabled = true

	sprite.visible = false

	await get_tree().create_timer(0.2).timeout
	queue_free()



	# 🔻 When player enters the enemy’s hit area
func _on_body_entered(body):
	if body.is_in_group("player"):
		print("[Enemy] Player entered range.")
		player_in_range = body
		_deal_damage()


	# 🔺 When player exits
func _on_body_exited(body):
	if body.is_in_group("player"):
		print("[Enemy] Player exited range.")
		player_in_range = null


	# 💥 Deal contact damage
func _deal_damage():
	if is_hurt:         
		return
	if not can_damage or player_in_range == null:
		return

	if player_in_range.has_method("take_damage"):
		print("[Enemy] Dealing", damage, "damage to player.")
		player_in_range.take_damage(damage, global_position)
	else:
		print("[Enemy] Player lacks take_damage()!")

	can_damage = false
	damage_timer.start(damage_cooldown)


func _on_DamageTimer_timeout():
	can_damage = true
	if player_in_range:
		_deal_damage()
func stop_combat():
	if is_chasing:
		is_chasing = false
		Combatmusicmanager.enemy_stopped_combat()
		
func _physics_process(delta):
	if is_on_wall():
		var collision = get_last_slide_collision()
		if collision:
			var normal = collision.get_normal()
			wander_direction = wander_direction.bounce(normal).normalized()
			global_position += normal * 2.0   # tiny push away
	if velocity.x != 0:
		sprite.flip_h = velocity.x > 0
	if is_knocked_back:
		velocity = knockback_vector
		knockback_vector = knockback_vector.move_toward(Vector2.ZERO, knockback_force * delta)

		if knockback_vector.length() < 10:
			is_knocked_back = false
			velocity = Vector2.ZERO
	else:
		if is_hurt:
			velocity = Vector2.ZERO
		elif is_alerted:
			velocity = Vector2.ZERO
		elif is_chasing and target:
			var dir = (target.global_position - global_position).normalized()
			velocity = dir * move_speed

		else:
	# 🐾 Wander behavior
			velocity = wander_direction * wander_speed

	move_and_slide()
