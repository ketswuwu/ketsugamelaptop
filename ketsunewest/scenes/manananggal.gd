extends CharacterBody2D
signal boss_hp_changed(current: int, max: int)
signal boss_started(max: int)
signal boss_died
@export var max_health: int = 50
@onready var sfx_dizzy: AudioStreamPlayer = get_node("#cartoonDizzySoundEffect")
@onready var sfx_scream: AudioStreamPlayer = $ScreamWithEchoSoundEffect
@export var arena_rect := Rect2(Vector2(-723, -2358), Vector2(1161, 739))

@export var reset_health_on_respawn := true

var _spawn_pos: Vector2
var _spawn_rot: float

@export var flight_speed: float = 800.0
@export var dash_speed: float = 1500.0

# Phase 1 landing
@export var land_interval: float = 8.0
@export var land_duration: float = 2.0
@export var landing_point: Vector2 = Vector2(-147.0, -1926.0)
@export var return_to_land_speed: float = 500.0

# Phase 2 dash + tired landing
@export var phase2_dash_every: float = 1.6
@export var phase2_fly_before_tired: float = 15.0
@export var tired_duration: float = 2.0

# Boss -> player contact damage (Area2D based)
@export var contact_damage: int = 2
@export var contact_damage_cooldown: float = 0.5

# Anim names
@export var anim_idle: String = "idle"
@export var anim_landed: String = "landed"
@export var anim_screaming: String = "screaming"
@export var anim_initiate_dash: String = "initiate_dash"
@export var anim_dashing: String = "dashing"
@export var anim_stunned: String = "stunned" # used when tired

# Safety timings (prevents hanging if anim signals are flaky)
@export var scream_fallback: float = 0.45
@export var initiate_fallback: float = 0.15
@export var dash_max_time: float = 0.65

@onready var anim: AnimatedSprite2D = $AnimatedSprite2D
@onready var detection: Area2D = $DetectionArea
@onready var hurtbox: Area2D = $Hurtbox
@onready var hurtbox_shape: CollisionShape2D = $Hurtbox/CollisionShape2D
@onready var pillar_hitbox: Area2D = get_node_or_null("PillarHitbox")

# Area2D that damages player on touch (Boss/ContactDamage)
@onready var contact_damage_area: Area2D = $ContactDamage

# Phase 2 special attack
@export var special_attack_chance: float = 0.50
@export var special_dash_gap: float = 0.12

var attack_screams_left: int = 0
var special_attack_active: bool = false
var queued_second_dash: bool = false
var scream_task_running: bool = false

# --- IMPORTANT for your player script ---
var is_flying: bool = true
var is_invulnerable: bool = false

# Prevent double-scream issues
var just_started_phase2: bool = false
var awaiting_dash_after_scream: bool = false

enum Phase { PHASE1, PHASE2 }
enum BossState { FLY, RETURN_TO_LAND, LAND_PHASE1, SCREAM, INIT_DASH, DASH, TIRED }

var phase: int = Phase.PHASE1
var state: int = BossState.FLY

var hp: int
var player: Node2D = null

var flight_target: Vector2
var dash_target: Vector2

var land_timer: float = 0.0
var land_time_left: float = 0.0

var dash_cooldown_left: float = 0.0
var dash_time_left: float = 0.0
var phase2_fatigue_left: float = 0.0
var tired_time_left: float = 0.0

# Contact damage state
var player_in_contact: Node2D = null
var contact_can_damage: bool = true


func _ready() -> void:
	add_to_group("respawn_reset") # so Respawn can find it
	_spawn_pos = global_position
	_spawn_rot = global_rotation
	hp = max_health
	emit_signal("boss_started", max_health)
	emit_signal("boss_hp_changed", hp, max_health)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

	# ✅ Ignore ALL physics collisions (prevents getting stuck on walls/pillars)
	collision_layer = 0
	collision_mask = 0

	# Player detection for targeting (Area2D)
	detection.body_entered.connect(_on_detection_body_entered)
	detection.body_exited.connect(_on_detection_body_exited)

	# Contact damage (Area2D)
	contact_damage_area.body_entered.connect(_on_contact_body_entered)
	contact_damage_area.body_exited.connect(_on_contact_body_exited)

	# Optional pillar stun while dashing (Area2D)
	if pillar_hitbox:
		pillar_hitbox.body_entered.connect(_on_pillar_hitbox_body_entered)

	_pick_flight_target()
	land_timer = land_interval

	_set_hurtbox_enabled(false)
	_set_flying(true)
	_play(anim_idle)

func reset_on_respawn() -> void:
	# Stop motion
	velocity = Vector2.ZERO
	move_and_slide()

	# Reset transform
	global_position = _spawn_pos
	global_rotation = _spawn_rot

	# Reset core boss state
	phase = Phase.PHASE1
	state = BossState.FLY

	# Reset HP + UI signals
	if reset_health_on_respawn:
		hp = max_health
		emit_signal("boss_started", max_health)
		emit_signal("boss_hp_changed", hp, max_health)

	# Clear targeting / contact damage
	player = null
	player_in_contact = null
	contact_can_damage = true

	# Reset timers / counters
	land_timer = land_interval
	land_time_left = 0.0
	dash_cooldown_left = 0.0
	dash_time_left = 0.0
	phase2_fatigue_left = 0.0
	tired_time_left = 0.0

	# Reset special attack flags
	attack_screams_left = 0
	special_attack_active = false
	queued_second_dash = false
	scream_task_running = false
	just_started_phase2 = false
	awaiting_dash_after_scream = false

	# Restore baseline mode/collisions (same as _ready)
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 0
	collision_mask = 0

	_set_hurtbox_enabled(false)
	_set_flying(true)
	_pick_flight_target()
	_play(anim_idle)
	
func _play_sfx(player: Node) -> void:
	if player == null:
		return
	# Works for AudioStreamPlayer or AudioStreamPlayer2D
	if player.has_method("stop"):
		player.stop()
	if player.has_method("play"):
		player.play()

func _play_scream_sfx() -> void:
	_play_sfx(sfx_scream)

func _play_dizzy_sfx() -> void:
	_play_sfx(sfx_dizzy)

func _physics_process(delta: float) -> void:
	# =========================
	# WAIT UNTIL BOSS IS ALLOWED TO MOVE
	# =========================
	# (State is your autoload singleton)
	if not ("boss_can_move" in State) or State.boss_can_move != true:
		# Freeze all motion + don't run AI timers/states
		velocity = Vector2.ZERO
		move_and_slide()

		# Keep a consistent look while paused
		_update_animation_default()
		return

	# =========================
	# NORMAL BOSS LOGIC
	# =========================
	if dash_cooldown_left > 0.0:
		dash_cooldown_left -= delta

	if phase == Phase.PHASE1:
		_phase1_update(delta)
	else:
		_phase2_update(delta)

	_do_movement(delta)
	move_and_slide()

	# Clamp to arena
	global_position.x = clamp(global_position.x, arena_rect.position.x, arena_rect.position.x + arena_rect.size.x)
	global_position.y = clamp(global_position.y, arena_rect.position.y, arena_rect.position.y + arena_rect.size.y)

	_update_animation_default()
# =========================
# Detection (targeting)
# =========================
func _on_detection_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player = body as Node2D

func _on_detection_body_exited(body: Node) -> void:
	if body == player:
		player = null


# =========================
# Contact damage (boss -> player)
# =========================
func _on_contact_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_in_contact = body as Node2D
		_try_deal_contact_damage()

func _on_contact_body_exited(body: Node) -> void:
	if body == player_in_contact:
		player_in_contact = null

func _try_deal_contact_damage() -> void:
	# Only deal contact damage while flying (your rule)
	if not is_flying:
		return

	# Optional: don't damage while screaming/initiating/tired
	if state in [BossState.SCREAM, BossState.INIT_DASH, BossState.TIRED]:
		return

	if not contact_can_damage:
		return
	if not is_instance_valid(player_in_contact):
		return

	if player_in_contact.has_method("take_damage"):
		player_in_contact.take_damage(contact_damage, global_position)

	contact_can_damage = false
	call_deferred("_contact_damage_cooldown_async")

func _contact_damage_cooldown_async() -> void:
	await get_tree().create_timer(contact_damage_cooldown).timeout
	contact_can_damage = true
	# If still touching, damage again
	if is_instance_valid(player_in_contact):
		_try_deal_contact_damage()


# =========================
# Damage API (matches your Hurtbox)
# =========================
func take_damage(amount: int, from_position: Vector2) -> void:
	# Only take damage when hittable
	if not _is_hittable():
		return

	hp -= amount
	emit_signal("boss_hp_changed", hp, max_health)
	# Phase transition at half HP
	if phase == Phase.PHASE1 and hp <= max_health / 2:
		_start_phase2()

	# 🔥 Death condition now requires salt
	if hp <= 0:
		_try_die()

func _try_die() -> void:
	if not ("salt" in State):
		return

	if State.salt != "got":
		hp = 1
		return

	State.boss = "dead"
	emit_signal("boss_died")
	queue_free()
func _is_hittable() -> bool:
	return (phase == Phase.PHASE1 and state == BossState.LAND_PHASE1) \
		or (phase == Phase.PHASE2 and state == BossState.TIRED)


func _start_phase2() -> void:
	phase = Phase.PHASE2
	phase2_fatigue_left = phase2_fly_before_tired

	just_started_phase2 = true
	awaiting_dash_after_scream = false
	dash_cooldown_left = phase2_dash_every

	_set_hurtbox_enabled(false)
	_set_flying(true)
	_enter_state(BossState.SCREAM)


# =========================
# Phase logic
# =========================
func _phase1_update(delta: float) -> void:
	if state == BossState.FLY:
		land_timer -= delta
		if land_timer <= 0.0:
			_enter_state(BossState.RETURN_TO_LAND)

	if state == BossState.LAND_PHASE1:
		land_time_left -= delta
		if land_time_left <= 0.0:
			land_timer = land_interval
			_pick_flight_target()
			_enter_state(BossState.FLY)


func _phase2_update(delta: float) -> void:
	# fatigue counts down while in air states
	if state in [BossState.FLY, BossState.SCREAM, BossState.INIT_DASH, BossState.DASH]:
		phase2_fatigue_left -= delta
		if phase2_fatigue_left <= 0.0:
			awaiting_dash_after_scream = false
			special_attack_active = false
			queued_second_dash = false
			attack_screams_left = 0
			_enter_state(BossState.TIRED)

	if state == BossState.TIRED:
		tired_time_left -= delta
		if tired_time_left <= 0.0:
			phase2_fatigue_left = phase2_fly_before_tired
			_pick_flight_target()
			_enter_state(BossState.FLY)

	if state == BossState.FLY and not just_started_phase2:
		if awaiting_dash_after_scream:
			if is_instance_valid(player) and dash_cooldown_left <= 0.0:
				dash_target = player.global_position
				awaiting_dash_after_scream = false
				_enter_state(BossState.INIT_DASH)
			return

		if dash_cooldown_left <= 0.0 and is_instance_valid(player):
			special_attack_active = randf() < special_attack_chance
			queued_second_dash = false
			attack_screams_left = 2 if special_attack_active else 1

			awaiting_dash_after_scream = true
			_enter_state(BossState.SCREAM)
			return


# =========================
# State machine
# =========================
func _enter_state(new_state: int) -> void:
	# ✅ Allow SCREAM to re-enter so we can scream twice for special attacks
	if state == new_state:
		if new_state == BossState.SCREAM:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			velocity = Vector2.ZERO
			_play(anim_screaming)

			_play_scream_sfx() # ✅ scream sound

			call_deferred("_scream_then_continue_async")
		return

	state = new_state

	match state:
		BossState.FLY:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			_play(anim_idle)

		BossState.RETURN_TO_LAND:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			_play(anim_idle)

		BossState.LAND_PHASE1:
			land_time_left = land_duration
			_set_hurtbox_enabled(true)
			_set_flying(false)
			_play(anim_landed)

		BossState.SCREAM:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			velocity = Vector2.ZERO
			_play(anim_screaming)
			_play_scream_sfx() # ✅ scream sound
			call_deferred("_scream_then_continue_async")

		BossState.INIT_DASH:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			velocity = Vector2.ZERO
			_play(anim_initiate_dash)
			call_deferred("_init_then_dash_async")

		BossState.DASH:
			_set_hurtbox_enabled(false)
			_set_flying(true)
			dash_time_left = dash_max_time
			_play(anim_dashing)

		BossState.TIRED:
			scream_task_running = false
			tired_time_left = tired_duration
			_set_hurtbox_enabled(true)
			_set_flying(false)
			velocity = Vector2.ZERO
			_play(anim_stunned)
			_play_dizzy_sfx() # ✅ dizzy sound
			dash_cooldown_left = phase2_dash_every


func _scream_then_continue_async() -> void:
	if scream_task_running:
		return
	scream_task_running = true

	await _await_anim_done(anim_screaming, scream_fallback)

	if just_started_phase2:
		just_started_phase2 = false
		awaiting_dash_after_scream = false
		attack_screams_left = 0
		special_attack_active = false
		queued_second_dash = false
		scream_task_running = false
		_enter_state(BossState.FLY)
		return

	if attack_screams_left > 1:
		attack_screams_left -= 1
		scream_task_running = false
		_enter_state(BossState.SCREAM)
		return

	attack_screams_left = 0

	if phase == Phase.PHASE2 and phase2_fatigue_left > 0.0:
		if is_instance_valid(player):
			dash_target = player.global_position
			awaiting_dash_after_scream = false
			queued_second_dash = special_attack_active
			scream_task_running = false
			_enter_state(BossState.INIT_DASH)
			return
		else:
			awaiting_dash_after_scream = true
			scream_task_running = false
			_enter_state(BossState.FLY)
			return

	awaiting_dash_after_scream = false
	special_attack_active = false
	queued_second_dash = false
	scream_task_running = false
	_enter_state(BossState.FLY)

func _init_then_dash_async() -> void:
	await _await_anim_done(anim_initiate_dash, initiate_fallback)

	if phase != Phase.PHASE2 or not is_instance_valid(player) or phase2_fatigue_left <= 0.0:
		awaiting_dash_after_scream = false
		_enter_state(BossState.FLY)
		return

	_enter_state(BossState.DASH)

func _start_second_dash_after_gap() -> void:
	await get_tree().create_timer(special_dash_gap).timeout
	if phase != Phase.PHASE2:
		return
	if phase2_fatigue_left <= 0.0:
		return
	if not is_instance_valid(player):
		special_attack_active = false
		dash_cooldown_left = phase2_dash_every
		_pick_flight_target()
		_enter_state(BossState.FLY)
		return

	dash_target = player.global_position
	_enter_state(BossState.DASH)


# =========================
# Movement
# =========================
func _do_movement(delta: float) -> void:
	match state:
		BossState.FLY:
			var dir := global_position.direction_to(flight_target)
			velocity = dir * flight_speed
			if global_position.distance_to(flight_target) < 20.0:
				_pick_flight_target()

		BossState.RETURN_TO_LAND:
			var dir := global_position.direction_to(landing_point)
			velocity = dir * return_to_land_speed
			if global_position.distance_to(landing_point) < return_to_land_speed * delta:
				global_position = landing_point
				velocity = Vector2.ZERO
				_enter_state(BossState.LAND_PHASE1)

		BossState.LAND_PHASE1, BossState.SCREAM, BossState.INIT_DASH, BossState.TIRED:
			velocity = Vector2.ZERO

		BossState.DASH:
			dash_time_left -= delta
			var dir := global_position.direction_to(dash_target)
			velocity = dir * dash_speed

			if global_position.distance_to(dash_target) < 20.0 or dash_time_left <= 0.0:
				if phase == Phase.PHASE2 and queued_second_dash and phase2_fatigue_left > 0.0:
					queued_second_dash = false
					velocity = Vector2.ZERO
					call_deferred("_start_second_dash_after_gap")
					return

				special_attack_active = false
				dash_cooldown_left = phase2_dash_every
				_pick_flight_target()
				_enter_state(BossState.FLY)


# =========================
# Pillar -> tired (optional)
# =========================
func _on_pillar_hitbox_body_entered(body: Node) -> void:
	if phase != Phase.PHASE2:
		return
	if state != BossState.DASH:
		return
	if body.is_in_group("pillars"):
		awaiting_dash_after_scream = false
		_enter_state(BossState.TIRED)


# =========================
# Helpers
# =========================
func _pick_flight_target() -> void:
	flight_target = Vector2(
		randf_range(arena_rect.position.x, arena_rect.position.x + arena_rect.size.x),
		randf_range(arena_rect.position.y, arena_rect.position.y + arena_rect.size.y)
	)

func _set_hurtbox_enabled(enabled: bool) -> void:
	if is_instance_valid(hurtbox):
		hurtbox.monitoring = enabled
	if is_instance_valid(hurtbox_shape):
		hurtbox_shape.disabled = not enabled

func _set_flying(value: bool) -> void:
	is_flying = value
	is_invulnerable = false

func _play(name: String) -> void:
	if anim.sprite_frames and anim.sprite_frames.has_animation(name):
		if anim.animation != name:
			anim.play(name)
		else:
			anim.frame = 0
			anim.play(name)

func _await_anim_done(name: String, fallback: float = 0.2) -> void:
	if anim == null or anim.sprite_frames == null or not anim.sprite_frames.has_animation(name):
		await get_tree().create_timer(max(0.05, fallback)).timeout
		return

	if anim.animation != name or not anim.is_playing():
		anim.play(name)

	var frames := anim.sprite_frames.get_frame_count(name)
	var fps := anim.sprite_frames.get_animation_speed(name)
	var duration := fallback
	if frames > 0 and fps > 0.0:
		duration = max(duration, float(frames) / float(fps))

	var loop := anim.sprite_frames.get_animation_loop(name)
	var timeout := duration + 0.1
	var timer := get_tree().create_timer(timeout)

	while timer.time_left > 0.0:
		if anim.animation != name:
			break
		if not loop and not anim.is_playing():
			break
		await get_tree().process_frame

func _update_animation_default() -> void:
	if state in [BossState.FLY, BossState.RETURN_TO_LAND]:
		_play(anim_idle)
	elif state == BossState.LAND_PHASE1:
		_play(anim_landed)
