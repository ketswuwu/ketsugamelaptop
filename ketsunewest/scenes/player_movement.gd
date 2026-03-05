extends CharacterBody2D

const BULLET_SCENE := preload("res://scenes/bullet.tscn")
@export var health_potion_heal_amount := 8
@onready var bite_sound: AudioStreamPlayer = $Bite
@onready var swing: AudioStreamPlayer = $Swing
@onready var crossbow_stretch: AudioStreamPlayer = $CrossbowStretch
@onready var crossbow_fire: AudioStreamPlayer = $CrossbowFire
@onready var heal_sound: AudioStreamPlayer = $Heal
@export var aim_rumble_weak := 0.50
@export var aim_rumble_strong := 0.5
@export var aim_rumble_refresh_time := 0.1
var _aim_rumble_timer := 0.0
var _aiming_last_frame := false
@onready var aim_indicator: Node2D = $AimIndicator
@onready var muzzle: Marker2D = $Muzzle
@export var swing_pitch_min := 0.9
@export var swing_pitch_max := 1.15
@export var aim_distance := 120.0
@export var aim_deadzone := 0.25
@export var bite_pitch_min := 0.95
@export var bite_pitch_max := 1.1
var current_aim_dir: Vector2 = Vector2.RIGHT
var _last_aim_anim_dir := ""
@onready var hit_sound: AudioStreamPlayer = $Hit
@export var hit_pitch_min := 0.9
@export var hit_pitch_max := 1.15

@export var hurt_lock_time := 0.25
@export var knockback_multiplier_on_hit := 1.35
@export var aim_down_move_multiplier := 0.55 # 55% speed while aiming down
var is_hit_locked := false
@export var lunge_time := 0.16
@export var lunge_slowdown := 0.18
@export var move_speed: float = 500
@export var attack_duration: float = 0.20
@export var invulnerability_time: float = 0.6
@export var flicker_speed: float = 0.1
@export var knockback_force: float = 600.0
@export var knockback_duration: float = 0.2
@export var dash_speed: float = 1200
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 0.5
@export var max_blood: int = 100
@export var blood_gain_per_hit: int = 8
@export var bite_lunge_force := 1000
@export var bite_lunge_duration := 0.12

var current_blood: int = 0

# ===== RANGED AIM/SHOOT =====
@export var ranged_speed := 1200.0
@export var ranged_cooldown := 0.18

var is_aiming := false
var is_shooting := false
var can_ranged := true

var aim_dir := Vector2.RIGHT
var aim_anim_dir := "side" # "up", "down", "side"

var dash_cost := 0

@onready var main_camera: Camera2D = get_viewport().get_camera_2d()

var is_dashing: bool = false
var can_dash: bool = true
var is_invincible: bool = false
var is_biting := false
var bite_target: Node = null

var knockback_vector: Vector2 = Vector2.ZERO
var is_knocked_back: bool = false

var current_health: int
var is_hurt: bool = false

# ✅ IMPORTANT: initialize, so .x/.y assignments never error
var character_direction: Vector2 = Vector2.ZERO

@onready var animated_sprite_2d: AnimatedSprite2D = $sprite
@onready var attack_hitbox: Area2D = $AttackHitbox
@onready var attack_shape: CollisionShape2D = $AttackHitbox/CollisionShape2D
@onready var attack_timer: Timer = $AttackTimer
@onready var attack_combo_timer: Timer = $AttackComboTimer
@onready var attack_lunge_timer: Timer = $AttackLungeTimer
@onready var hurt_timer: Timer = $HurtTimer
@onready var dash_timer: Timer = $DashTimer
@onready var dash_cooldown_timer: Timer = $DashCooldownTimer
@onready var interact_box: Area2D = $Direction/ActionableFinder
@onready var bite_hitbox: Area2D = $BiteHitbox
@onready var bite_lunge_timer: Timer = $BiteLungeTimer
@onready var blood_bar: ProgressBar = get_tree().get_current_scene().get_node("UI/BloodBar")
@onready var hp_bar: ProgressBar = get_tree().get_current_scene().get_node("UI/HPBar")

@export var bite_cost := 50
@export var bite_damage := 15
@export var bite_heal := 5
@export var bite_duration := 0.35

var normal_collision_layer
var normal_collision_mask
var last_move_dir: Vector2 = Vector2.RIGHT
var is_lunging: bool = false
var can_deal_damage: bool = false
var animation_direction: String = "down"
var enemies_hit_this_swing := {}

var is_attacking: bool = false
var combo_step: int = 0
var max_combo: int = 3
var combo_window: float = 0.8
var lunge_force := [150, 150, 450]

var attack_offset := {
	"up": Vector2(0, -32),
	"down": Vector2(0, 32),
	"side": Vector2(32, 0)
}

func _ready():
	main_camera = get_viewport().get_camera_2d()
	if aim_indicator:
		aim_indicator.visible = false

	bite_hitbox.monitoring = false
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask

	current_health = Playerdata.stats["health"]
	Playerdata.lock_ability("Double Jump")
	Playerdata.unlock_ability("Dash")

	current_blood = 0
	update_blood_ui()
	update_hp_ui()

func _handle_aim_rumble(delta: float) -> void:
	# If no controller connected, do nothing
	if Input.get_connected_joypads().is_empty():
		return

	var device := Input.get_connected_joypads()[0]

	if is_aiming:
		_aim_rumble_timer -= delta

		# Refresh rumble every small interval
		if _aim_rumble_timer <= 0.0:
			Input.start_joy_vibration(
				device,
				aim_rumble_weak,
				aim_rumble_strong,
				aim_rumble_refresh_time
			)
			_aim_rumble_timer = aim_rumble_refresh_time
	else:
		# Stop rumble when aim released
		if _aiming_last_frame:
			Input.stop_joy_vibration(device)

	_aiming_last_frame = is_aiming
func _physics_process(delta: float) -> void:
	_handle_aim_rumble(delta)
	_update_aim_down_camera()
	if is_hit_locked:
		# keep physics running so knockback movement continues
		move_and_slide()
		return

	# =====================================================
	# HARD LOCK (Dialogue / Cutscenes / etc.)
	# =====================================================
	if not State.player_can_move:
		is_aiming = false
		if aim_indicator:
			aim_indicator.visible = false
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# =====================================================
	# Aim indicator is ONLY visible while holding shoot_ranged
	# =====================================================
	if aim_indicator:
		aim_indicator.visible = is_aiming

	# =====================================================
	# SHOOTING LOCK (Stop movement during shoot animation)
	# =====================================================
	if is_shooting:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	# =====================================================
	# ATTACKING (melee lunge system unchanged)
	# =====================================================
	if is_attacking:
		move_and_slide()
		return

	if is_lunging:
		velocity = velocity.lerp(Vector2.ZERO, lunge_slowdown)
	elif is_dashing:
		move_and_slide()
		return
	else:
		# =====================================================
		# MOVEMENT INPUT
		# =====================================================
		character_direction.x = Input.get_axis("move_left", "move_right")
		character_direction.y = Input.get_axis("move_up", "move_down")
		character_direction = character_direction.normalized()

		var input_dir := Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up")
		).normalized()

		if input_dir != Vector2.ZERO:
			last_move_dir = input_dir

		update_sprite_direction(character_direction)
		update_interact_box_direction()

		# =====================================================
		# AIMING (movement allowed while holding)
		# =====================================================
		if is_aiming:
			aim_dir = _get_aim_vector()
			aim_anim_dir = _aim_dir_to_anim_dir(aim_dir)
			
			_update_aim_down_camera()
			
			if aim_anim_dir == "side":
				%sprite.flip_h = aim_dir.x < 0.0

			# If not still playing initiate, loop aim
			# ✅ Always switch aim animation when direction changes
			if _last_aim_anim_dir != aim_anim_dir:
				_last_aim_anim_dir = aim_anim_dir

	# Optional: play initiate each time you change direction
	# (If you DON'T want initiate when rotating, comment this out)
				#_play_aim_initiate(aim_anim_dir)

				_play_aim_loop(aim_anim_dir)

# ✅ If we're not currently in initiate, make sure we're looping the correct aim
			if not animated_sprite_2d.animation.begins_with("aim_initiate_"):
				_play_aim_loop(aim_anim_dir)

			# 🎯 Aim indicator emanates from muzzle marker (matches bullet spawn)
			if aim_indicator:
				var origin := Vector2.ZERO
				if muzzle:
					origin = muzzle.position # local position (indicator is also local)
				aim_indicator.position = origin + (aim_dir * aim_distance)
				aim_indicator.rotation = aim_dir.angle()
		else:
			# =====================================================
			# NORMAL WALK / IDLE (only if not aiming)
			# =====================================================
			if character_direction != Vector2.ZERO:
				animated_sprite_2d.play("walk_" + animation_direction)
			else:
				animated_sprite_2d.play("idle_" + animation_direction)

		# =====================================================
		# SPRITE FLIP FOR SIDE MOVEMENT (only if not aiming)
		# =====================================================
		if not is_aiming:
			if character_direction.x > 0:
				%sprite.flip_h = false
				$AttackHitbox.position.x = abs($AttackHitbox.position.x)
			elif character_direction.x < 0:
				%sprite.flip_h = true
				$AttackHitbox.position.x = -abs($AttackHitbox.position.x)

		var speed_mul := 1.0
		
# Only slow while aiming AND aiming direction is "down"
		if is_aiming:
			speed_mul = aim_down_move_multiplier

		velocity = character_direction * move_speed * speed_mul
		move_and_slide()

	# =====================================================
	# INPUT CHECKS (ONLY HERE — no duplicate in _unhandled_input)
	# =====================================================

	# Melee
	if Input.is_action_just_pressed("attack_melee") and not is_attacking and not is_dashing and not is_shooting:
		start_attack()

	# Dash
	if Input.is_action_just_pressed("dash") and can_dash and not is_attacking and not is_shooting:
		if spend_blood(dash_cost):
			start_dash()

	# Bite
	if Input.is_action_just_pressed("bite") and not is_attacking and not is_dashing and not is_shooting:
		if spend_blood(bite_cost):
			start_bite()
	#	 Health Potion (one-time) - press interact_1
	if Input.is_action_just_pressed("interact_1") and State.player_can_move:
		_try_use_health_potion()
	# Ranged AIM START (hold)
	if Input.is_action_just_pressed("shoot_ranged") and not is_attacking and not is_dashing and not is_shooting:
		start_ranged_aim()

	# Ranged RELEASE (fire)
	if is_aiming and Input.is_action_just_released("shoot_ranged"):
		release_ranged_shot()
func _update_aim_down_camera() -> void:
	if not is_instance_valid(main_camera):
		main_camera = get_viewport().get_camera_2d()
	if not is_instance_valid(main_camera):
		return

	if main_camera.has_method("set_aim_down_cinematic"):
		main_camera.set_aim_down_cinematic(is_aiming)
func _get_aim_vector() -> Vector2:
	# ✅ Match YOUR project input names:
	var stick := Input.get_vector("aim_left", "aim_right", "aim_up", "aim_down")
	if stick.length() >= aim_deadzone:
		return stick.normalized()

	return (get_global_mouse_position() - global_position).normalized()

func _aim_dir_to_anim_dir(dir: Vector2) -> String:
	if abs(dir.x) > abs(dir.y):
		return "side"
	return "down" if dir.y > 0.0 else "up"

func _play_aim_initiate(anim_dir: String) -> void:
	var anim_name := "aim_initiate_" + anim_dir
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _play_aim_loop(anim_dir: String) -> void:
	var anim_name := "aim_" + anim_dir
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _play_shoot(anim_dir: String) -> void:
	var anim_name := "shoot_" + anim_dir
	if animated_sprite_2d.sprite_frames.has_animation(anim_name):
		animated_sprite_2d.play(anim_name)

func _spawn_bullet(dir: Vector2) -> void:
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT

	var b := BULLET_SCENE.instantiate()
	get_tree().current_scene.add_child(b)

	# Spawn from marker (same origin as indicator)
	if muzzle:
		b.global_position = muzzle.global_position
	else:
		b.global_position = global_position

	# Optional: prevent immediate self-collision if you ever enable it
	if b.has_method("add_collision_exception_with"):
		b.add_collision_exception_with(self)

	if b.has_method("setup"):
		b.setup(dir, ranged_speed)

func start_ranged_aim() -> void:
	if is_shooting or not can_ranged:
		return

	is_aiming = true
	if crossbow_stretch and not crossbow_stretch.playing:
		crossbow_stretch.play()
	aim_dir = _get_aim_vector()
	aim_anim_dir = _aim_dir_to_anim_dir(aim_dir)
	_update_aim_down_camera()
	if aim_anim_dir == "side":
		%sprite.flip_h = aim_dir.x < 0.0

	_play_aim_initiate(aim_anim_dir)
	_update_aim_down_camera()
func release_ranged_shot() -> void:
	if not is_aiming or is_shooting:
		return

	is_aiming = false
	_last_aim_anim_dir = ""
	_update_aim_down_camera()
	is_shooting = true
	can_ranged = false
	# 🧼 Stop stretch sound immediately
	if crossbow_stretch and crossbow_stretch.playing:
		crossbow_stretch.stop()

	# 💥 Play fire sound
	if crossbow_fire:
		crossbow_fire.play()
	if aim_indicator:
		aim_indicator.visible = false

	aim_dir = _get_aim_vector()
	aim_anim_dir = _aim_dir_to_anim_dir(aim_dir)

	if aim_anim_dir == "side":
		%sprite.flip_h = aim_dir.x < 0.0

	velocity = Vector2.ZERO
	move_and_slide()

	_play_shoot(aim_anim_dir)
	_spawn_bullet(aim_dir)

	await _await_anim_done_safe(animated_sprite_2d.animation, 0.05)

	is_shooting = false

	await get_tree().create_timer(ranged_cooldown).timeout
	can_ranged = true

# ======================
# Damage / Knockback
# ======================
func take_damage(amount: int, source_position: Vector2 = global_position) -> void:
	if is_invincible or is_hurt:
		return

	# Lock FIRST so _physics_process can't overwrite animations this frame
	is_hit_locked = true

	# Cancel actions if hit
	if is_attacking:
		is_attacking = false
		can_deal_damage = false
		attack_hitbox.monitoring = false
		is_lunging = false

	is_aiming = false
	_last_aim_anim_dir = ""
	_update_aim_down_camera()
	is_shooting = false
	if aim_indicator:
		aim_indicator.visible = false

	# Play hurt (no direction)
	if animated_sprite_2d.sprite_frames and animated_sprite_2d.sprite_frames.has_animation("hurt"):
		animated_sprite_2d.frame = 0
		animated_sprite_2d.play("hurt")
	else:
		push_error("Missing 'hurt' animation on $sprite SpriteFrames")

	current_health -= amount
	Playerdata.stats["health"] = current_health
	update_hp_ui()

	if is_instance_valid(main_camera) and main_camera.has_method("start_hitstun_shake"):
		main_camera.start_hitstun_shake(10.0)

	is_hurt = true
	hurt_timer.start(invulnerability_time)

	# Stronger knockback
	var dir := (global_position - source_position).normalized()
	knockback_vector = dir * knockback_force * knockback_multiplier_on_hit
	is_knocked_back = true
	start_knockback()

	if current_health <= 0:
		die()
		return

	start_flicker_effect()

	await get_tree().create_timer(hurt_lock_time).timeout
	is_hit_locked = false
	if is_instance_valid(main_camera) and main_camera.has_method("stop_hitstun_shake"):
		main_camera.stop_hitstun_shake()

func start_knockback() -> void:
	var elapsed := 0.0
	while elapsed < knockback_duration and is_knocked_back:
		var t := elapsed / knockback_duration
		velocity = knockback_vector * (1.0 - t)
		move_and_slide()
		await get_tree().process_frame
		elapsed += get_process_delta_time()

	is_knocked_back = false
	velocity = Vector2.ZERO

func start_flicker_effect() -> void:
	if not is_instance_valid(animated_sprite_2d):
		return

	var flicker_interval := 0.1
	var flicker_count := int(invulnerability_time / flicker_interval / 2)

	for i in range(flicker_count):
		if not is_hurt:
			break
		animated_sprite_2d.modulate = Color(2, 2, 2, 1)
		await get_tree().create_timer(flicker_interval).timeout
		animated_sprite_2d.modulate = Color(1, 1, 1, 1)
		await get_tree().create_timer(flicker_interval).timeout

	animated_sprite_2d.modulate = Color(1, 1, 1, 1)

func _on_hurt_timer_timeout() -> void:
	is_hurt = false

func die() -> void:
	print("[Player] Player has died!")

	is_attacking = false
	is_hurt = false
	is_aiming = false
	_update_aim_down_camera()
	is_shooting = false

	if aim_indicator:
		aim_indicator.visible = false

	velocity = Vector2.ZERO
	State.player_can_move = false
	$CollisionShape2D.disabled = true

	if is_instance_valid(main_camera) and main_camera.has_method("apply_shake"):
		main_camera.apply_shake(25.0, 0.25)
	
	var death_anim = "dead_" + animation_direction
	if animated_sprite_2d.sprite_frames.has_animation(death_anim):
		await _await_anim_done_safe(death_anim, 0.1)
	else:
		await get_tree().create_timer(0.4).timeout
	if is_instance_valid(main_camera) and main_camera.has_method("stop_hitstun_shake"):
		main_camera.stop_hitstun_shake()
	Playerdata.stats["health"] = Playerdata.stats["max_health"]

	# ✅ IMPORTANT: mark what kind of death happened
	Respawn.set_last_death_boss(Respawn.in_boss_room)

	Respawn.respawn_player(self)
func on_respawned() -> void:
	# Re-enable gameplay after death
	is_hit_locked = false
	is_hurt = false
	is_invincible = false
	is_attacking = false
	is_shooting = false
	is_aiming = false
	_last_aim_anim_dir = ""
	if is_instance_valid(main_camera) and main_camera.has_method("stop_hitstun_shake"):
		main_camera.stop_hitstun_shake()
	velocity = Vector2.ZERO
	State.player_can_move = true

	if has_node("CollisionShape2D"):
		$CollisionShape2D.disabled = false

	# Restore health vars/UI
	current_health = Playerdata.stats["health"]
	update_hp_ui()
	update_blood_ui()

	# Optional: ensure camera aim zoom resets
	_update_aim_down_camera()
	
func _on_attack_lunge_timer_timeout() -> void:
	is_lunging = false
	# Do NOT zero velocity here — let it naturally ease out / be overwritten by movement.

# ======================
# Helpers
# ======================
func _await_anim_done_safe(anim_name: String, fallback_min: float = 0.1) -> void:
	if animated_sprite_2d == null or animated_sprite_2d.sprite_frames == null:
		await get_tree().create_timer(fallback_min).timeout
		return

	if not animated_sprite_2d.sprite_frames.has_animation(anim_name):
		await get_tree().create_timer(fallback_min).timeout
		return

	animated_sprite_2d.frame = 0
	animated_sprite_2d.play(anim_name)

	var frames := animated_sprite_2d.sprite_frames.get_frame_count(anim_name)
	var fps := animated_sprite_2d.sprite_frames.get_animation_speed(anim_name)
	var duration := fallback_min
	if frames > 0 and fps > 0.0:
		duration = max(duration, float(frames) / float(fps))

	await get_tree().create_timer(duration + 0.05).timeout

# ======================
# Your existing functions below (unchanged)
# ======================
func start_attack():
	enemies_hit_this_swing.clear()

	if attack_combo_timer.is_stopped():
		combo_step = 1
	else:
		combo_step += 1

	if combo_step > max_combo:
		combo_step = 1

	var anim_name = "attack_" + animation_direction + "_" + str(combo_step)
	animated_sprite_2d.play(anim_name)

	is_attacking = true
	
	# 🔊 PLAY SWING SOUND WITH RANDOM PITCH
	if swing:
		var combo_bonus := combo_step * 0.03
		swing.pitch_scale = randf_range(swing_pitch_min, swing_pitch_max) + combo_bonus
		swing.play()

	apply_lunge()

	update_attack_hitbox_direction()

	can_deal_damage = true
	attack_hitbox.monitoring = true
	attack_hitbox.set_deferred("monitorable", true)

	await _await_anim_done_safe(anim_name, 0.05)

	is_attacking = false
	can_deal_damage = false
	attack_hitbox.monitoring = false

	attack_combo_timer.start(combo_window)
func update_interact_box_direction():
	match animation_direction:
		"up":
			interact_box.position = Vector2(0, -80)
			interact_box.rotation_degrees = 0
		"down":
			interact_box.position = Vector2(0, 0)
			interact_box.rotation_degrees = 0
		"side":
			var x_offset = 40 if not %sprite.flip_h else -40
			interact_box.position = Vector2(x_offset, -40)
			interact_box.rotation_degrees = 0

func update_attack_hitbox_direction():
	match animation_direction:
		"up":
			attack_hitbox.position = Vector2(-40, -80)
			attack_hitbox.rotation_degrees = 90
		"down":
			attack_hitbox.position = Vector2(-40, -5)
			attack_hitbox.rotation_degrees = 90
		"side":
			var x_offset = -32 if %sprite.flip_h else 32
			attack_hitbox.position = Vector2(x_offset, 0)
			attack_hitbox.rotation_degrees = 0

func _on_attack_hitbox_area_entered(area: Area2D) -> void:
	if not can_deal_damage or not is_attacking:
		return

	if area.is_in_group("enemy_hurtbox"):
		var enemy := area.get_parent()
		if enemy == null:
			return

		if enemies_hit_this_swing.has(enemy):
			return

		if "is_flying" in enemy and enemy.is_flying:
			return

		if "is_invulnerable" in enemy and enemy.is_invulnerable:
			return

		enemies_hit_this_swing[enemy] = true

		var damage = Playerdata.stats["attack"]
		enemy.take_damage(damage, global_position)
# 🔊 PLAY HIT SOUND (random pitch)
		if hit_sound:
			hit_sound.pitch_scale = randf_range(hit_pitch_min, hit_pitch_max)
			hit_sound.play()
		add_blood(blood_gain_per_hit)
		return

	if area.is_in_group("breakable") and area.has_method("take_damage"):
		var damage = Playerdata.stats["attack"]
		area.take_damage(damage)

func apply_lunge():
	var force = lunge_force[combo_step - 1]
	velocity = last_move_dir * force
	is_lunging = true
	attack_lunge_timer.start(lunge_time)

func start_dash():
	if last_move_dir == Vector2.ZERO:
		return

	is_dashing = true
	normal_collision_layer = collision_layer
	normal_collision_mask = collision_mask

	collision_layer = 2
	collision_mask = 3

	velocity = last_move_dir.normalized() * dash_speed
	dash_timer.start(dash_duration)

func start_bite():
	is_biting = true
	is_attacking = true
	can_deal_damage = false
	# 🧛 PLAY BITE SOUND WITH RANDOM PITCH
	if bite_sound:
		bite_sound.pitch_scale = randf_range(bite_pitch_min, bite_pitch_max)
		bite_sound.play()
		
	animated_sprite_2d.play("bite_" + animation_direction)

	update_bite_hitbox_direction()
	bite_hitbox.monitoring = true

	await _await_anim_done_safe(animated_sprite_2d.animation, 0.05)
	end_bite()

func _on_bite_lunge_timer_timeout():
	is_lunging = false
	velocity = Vector2.ZERO

func update_bite_hitbox_direction():
	match animation_direction:
		"up":
			bite_hitbox.position = Vector2(0, -80)
			bite_hitbox.rotation_degrees = 0
		"down":
			bite_hitbox.position = Vector2(0, -5)
			bite_hitbox.rotation_degrees = 0
		"side":
			var x_offset = -50 if %sprite.flip_h else 50
			bite_hitbox.position = Vector2(x_offset, -45)
			bite_hitbox.rotation_degrees = 90

func _on_bite_hitbox_area_entered(area: Area2D):
	if not is_biting:
		return

	if area.is_in_group("enemy_hurtbox") and area.has_method("take_damage"):
		bite_target = area
		Hitstop.apply(0.01, 0.03)
		area.take_damage(bite_damage, global_position)
		heal(bite_heal)

		if main_camera:
			main_camera.apply_shake(12.0, 0.2)

		if area.has_method("set_hurt_lock"):
			area.set_hurt_lock(bite_duration)

func end_bite():
	is_biting = false
	is_attacking = false
	bite_hitbox.monitoring = false
	bite_target = null

func heal(amount: int):
	current_health = clamp(current_health + amount, 0, Playerdata.stats["max_health"])
	Playerdata.stats["health"] = current_health
	update_hp_ui()

func set_invincible(value: bool):
	is_invincible = value
	if value:
		animated_sprite_2d.modulate = Color(1, 0.4, 0.4, 0.8)
	else:
		animated_sprite_2d.modulate = Color(1, 1, 1, 1)

func _on_dash_timer_timeout() -> void:
	is_dashing = false
	set_invincible(false)
	collision_layer = normal_collision_layer
	collision_mask = normal_collision_mask

func _on_dash_cooldown_timer_timeout() -> void:
	can_dash = true

func add_blood(amount: int):
	current_blood = clamp(current_blood + amount, 0, max_blood)
	update_blood_ui()

func spend_blood(cost: int) -> bool:
	if current_blood < cost:
		return false
	current_blood -= cost
	update_blood_ui()
	return true

func update_blood_ui():
	if blood_bar:
		blood_bar.max_value = max_blood
		blood_bar.value = current_blood

func update_hp_ui():
	if hp_bar:
		hp_bar.max_value = Playerdata.stats["max_health"]
		hp_bar.value = current_health



func _try_use_health_potion() -> void:
	# Must exist and be bought
	if not ("health_potion" in State):
		return
	if State.health_potion != "bought":
		return

	var max_hp := int(Playerdata.stats["max_health"])

	# Don't use if already full
	if current_health >= max_hp:
		return

	# Heal
	current_health = clamp(current_health + health_potion_heal_amount, 0, max_hp)
	Playerdata.stats["health"] = current_health
	update_hp_ui()

	# 🔊 Play heal sound
	if heal_sound:
		heal_sound.stop()
		heal_sound.play()

	# Consume potion (cannot use again)
	State.health_potion = "used"

	print("Health potion used! (+%d HP)" % health_potion_heal_amount)
func _unhandled_input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("ui_accept") and State.player_can_move:
		var actionables = interact_box.get_overlapping_areas()
		if actionables.size() > 0:
			State.player_can_move = false
			actionables[0].action()

func update_sprite_direction(input: Vector2) -> void:
	if input == Vector2.ZERO:
		return

	if abs(input.x) > abs(input.y):
		animation_direction = "side"
	elif input.y > 0:
		animation_direction = "down"
	else:
		animation_direction = "up"
