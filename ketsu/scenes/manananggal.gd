extends CharacterBody2D

@export var max_health: int = 15
@export var damage: int = 1
@export var damage_cooldown: float = 0.5

# -------------------------
# Boss flying / arena setup
# -------------------------

@export var arena_rect := Rect2(
	Vector2(-723.0, -2358.0),
	Vector2(1161.0, 739.0)
)

@export var dash_pause_time := 0.5
@export var dash_speed := 1500.0
@export var dash_chance := 0.003
@export var flight_speed := 800.0
@export var flight_target_change_time := 2.0
@export var land_interval := 10.0
@export var land_duration := 2.0

@export var landing_point := Vector2(-147.0, -1926.0)
@export var return_to_land_speed := 500.0

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D

var is_returning_to_land := false
var is_dash_pausing := false
var is_dashing := false
var dash_target := Vector2.ZERO

var is_flying := true
var flight_target := Vector2.ZERO
var land_timer := 0.0
var land_time_left := 0.0

# -------------------------

var can_damage: bool = true
var player_in_range: Node = null
var current_health: int
var is_hurt: bool = false

@onready var hitbox: Area2D = $Area2D
@onready var damage_timer: Timer = $DamageTimer
@onready var sprite: Sprite2D = $Sprite2D

var target: Node2D = null


func _ready():
	current_health = max_health

	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	hitbox.body_entered.connect(_on_body_entered)
	hitbox.body_exited.connect(_on_body_exited)
	damage_timer.timeout.connect(_on_DamageTimer_timeout)

	_pick_flight_target()
	land_timer = land_interval

	collision_mask = 0


# -------------------------
# Dash attack
# -------------------------

func _start_dash_attack():
	if is_dash_pausing or is_dashing:
		return

	if target == null:
		return

	is_dash_pausing = true
	velocity = Vector2.ZERO

	await get_tree().create_timer(dash_pause_time).timeout

	if not is_flying:
		is_dash_pausing = false
		return

	if not is_instance_valid(target):
		is_dash_pausing = false
		return

	dash_target = target.global_position

	is_dash_pausing = false
	is_dashing = true


# -------------------------
# Arena helpers
# -------------------------

func _pick_flight_target():
	flight_target = Vector2(
		randf_range(arena_rect.position.x, arena_rect.position.x + arena_rect.size.x),
		randf_range(arena_rect.position.y, arena_rect.position.y + arena_rect.size.y)
	)


# -------------------------
# Detection
# -------------------------

func _on_detection_entered(body):
	if body.is_in_group("player"):
		target = body


func _on_detection_exited(body):
	if body == target:
		target = null


# -------------------------
# Damage taken
# -------------------------

func take_damage(amount: int, source_position: Vector2 = global_position):
	if is_flying:
		return

	if is_hurt:
		return

	is_hurt = true
	can_damage = false
	hitbox.monitoring = false

	current_health -= amount
	print("[Boss] Took damage:", amount, "remaining:", current_health)

	await get_tree().create_timer(0.25).timeout

	is_hurt = false
	hitbox.monitoring = true
	can_damage = true

	if current_health <= 0:
		if State.salt == "got":
			die()
		else:
			# Prevent negative stacking and keep boss at 1 HP
			current_health = 1
			print("[Boss] Cannot be killed yet. Salt not obtained.")

func die():
	print("[Boss] Died!")

	if has_node("CollisionShape2D"):
		$Area2D/CollisionShape2D.disabled = true

	anim.visible = false

	await get_tree().create_timer(0.2).timeout
	queue_free()


# -------------------------
# Contact damage
# -------------------------

func _on_body_entered(body):
	if body.is_in_group("player"):
		player_in_range = body
		_deal_damage()


func _on_body_exited(body):
	if body.is_in_group("player"):
		player_in_range = null


func _deal_damage():

	# only while flying
	if not is_flying:
		return

	if is_hurt:
		return

	if not can_damage or player_in_range == null:
		return

	if player_in_range.has_method("take_damage"):
		player_in_range.take_damage(damage, global_position)

	can_damage = false
	damage_timer.start(damage_cooldown)


func _on_DamageTimer_timeout():
	can_damage = true
	if player_in_range:
		_deal_damage()


# -------------------------
# Movement
# -------------------------

func _physics_process(delta):

	# -----------------
	# Timers
	# -----------------

	if is_flying and not is_returning_to_land and not is_dashing and not is_dash_pausing:
		land_timer -= delta

	if land_timer <= 0.0 and is_flying and not is_returning_to_land:
		is_returning_to_land = true

	if not is_flying:
		land_time_left -= delta

		if land_time_left <= 0.0:
			is_flying = true
			land_timer = land_interval
			_pick_flight_target()

	# -----------------
	# Movement
	# -----------------

	if is_flying:

		# returning to landing point
		if is_returning_to_land:

			var dist := global_position.distance_to(landing_point)

			if dist <= return_to_land_speed * delta:
				global_position = landing_point
				velocity = Vector2.ZERO

				is_returning_to_land = false
				is_flying = false
				land_time_left = land_duration
			else:
				var rdir := global_position.direction_to(landing_point)
				velocity = rdir * return_to_land_speed

		# normal flying
		else:

			if not is_dash_pausing and not is_dashing and randf() < dash_chance:
				_start_dash_attack()

			if is_dash_pausing:
				velocity = Vector2.ZERO

			elif is_dashing:
				var ddir := global_position.direction_to(dash_target)
				velocity = ddir * dash_speed

				if global_position.distance_to(dash_target) < 20.0:
					is_dashing = false
					_pick_flight_target()

			else:
				var fdir := global_position.direction_to(flight_target)
				velocity = fdir * flight_speed

				if global_position.distance_to(flight_target) < 20.0:
					_pick_flight_target()

	else:
		velocity = Vector2.ZERO


	move_and_slide()

	# -----------------
	# Clamp arena
	# -----------------

	global_position.x = clamp(
		global_position.x,
		arena_rect.position.x,
		arena_rect.position.x + arena_rect.size.x
	)

	global_position.y = clamp(
		global_position.y,
		arena_rect.position.y,
		arena_rect.position.y + arena_rect.size.y
	)
