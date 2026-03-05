extends CharacterBody2D

signal died(enemy)

@export var max_health: int = 10

@export var move_speed: float = 140.0
@export var flee_speed: float = 320.0

@export var attack_cooldown: float = 1.2
@export var projectile_scene: PackedScene
@export var projectile_damage: int = 1

# Optional: where the projectile spawns from (offset from enemy)
@export var projectile_spawn_offset: Vector2 = Vector2(24, -6)

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var hurtbox: Area2D = $Hurtbox
@onready var near_area: Area2D = $detectionareanear
@onready var range_area: Area2D = $detectionarearange

var current_health: int
var player: Node2D = null

var player_in_near: bool = false
var player_in_range: bool = false

var is_spawning: bool = true
var is_attacking: bool = false
var can_attack: bool = true


func _ready() -> void:
	current_health = max_health

	# Hook detection FIRST
	near_area.body_entered.connect(_on_near_entered)
	near_area.body_exited.connect(_on_near_exited)
	range_area.body_entered.connect(_on_range_entered)
	range_area.body_exited.connect(_on_range_exited)

	# Start spawn animation
	if anim.sprite_frames and anim.sprite_frames.has_animation("spawn"):
		anim.play("spawn")
		await anim.animation_finished

	is_spawning = false
	if anim.animation != "idle":
		anim.play("idle")

	# ✅ IMPORTANT: if player is already inside areas when we spawn, detect them now
	await get_tree().process_frame  # give physics one tick so overlaps are up to date
	_refresh_detection_from_overlaps()


func _refresh_detection_from_overlaps() -> void:
	# Ensure monitoring is on
	near_area.monitoring = true
	range_area.monitoring = true

	player_in_near = false
	player_in_range = false

	var found_player: Node2D = null

	# Check NEAR first (higher priority)
	for b in near_area.get_overlapping_bodies():
		if b is Node2D and b.is_in_group("player"):
			found_player = b
			player_in_near = true
			break

	# Check RANGE if we didn't find near (or even if we did, we can still track range)
	for b in range_area.get_overlapping_bodies():
		if b is Node2D and b.is_in_group("player"):
			if found_player == null:
				found_player = b
			player_in_range = true
			break

	player = found_player


func _physics_process(_delta: float) -> void:
	if is_spawning:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Priority 1: flee if player is close
	if player_in_near and is_instance_valid(player):
		_flee_from_player()
		move_and_slide()
		return

	# Priority 2: attack if player in range
	if player_in_range and is_instance_valid(player) and can_attack:
		_start_attack()
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# Otherwise idle
	velocity = Vector2.ZERO
	if anim.animation != "idle":
		anim.play("idle")
	move_and_slide()


func _flee_from_player() -> void:
	var dir: Vector2 = (global_position - player.global_position).normalized()
	velocity = dir * flee_speed

	if velocity.x != 0.0:
		anim.flip_h = velocity.x < 0.0

	if anim.animation != "idle":
		anim.play("idle")


func _start_attack() -> void:
	if is_attacking or not can_attack:
		return
	if projectile_scene == null:
		push_warning("projectile_scene not set on ranged enemy!")
		return
	if not is_instance_valid(player):
		return

	is_attacking = true
	can_attack = false

	var to_player: Vector2 = player.global_position - global_position
	if to_player.x != 0.0:
		anim.flip_h = to_player.x < 0.0

	anim.play("attack")

	await get_tree().create_timer(0.12).timeout
	_shoot_projectile()

	await anim.animation_finished
	is_attacking = false
	anim.play("idle")

	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true


func _shoot_projectile() -> void:
	if not is_instance_valid(player):
		return

	var proj := projectile_scene.instantiate()
	get_tree().current_scene.add_child(proj)

	var offset: Vector2 = projectile_spawn_offset
	offset.x = -abs(offset.x) if anim.flip_h else abs(offset.x)
	proj.global_position = global_position + offset

	var dir: Vector2 = (player.global_position - proj.global_position).normalized()

	if proj.has_method("setup"):
		proj.call("setup", dir, projectile_damage)
	else:
		push_warning("Projectile scene has no setup(dir, dmg) method!")


# -------------------------
# Detection signals
# -------------------------

func _on_near_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		player_in_near = true

func _on_near_exited(body: Node) -> void:
	if body == player:
		player_in_near = false
		if not player_in_range:
			player = null

func _on_range_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body
		player_in_range = true

func _on_range_exited(body: Node) -> void:
	if body == player:
		player_in_range = false
		if not player_in_near:
			player = null


# -------------------------
# Damage + death
# -------------------------

func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
	current_health -= amount
	if current_health <= 0:
		_die()

func _die() -> void:
	died.emit(self)
	queue_free()
