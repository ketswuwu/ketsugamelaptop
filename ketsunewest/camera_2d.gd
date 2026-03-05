extends Camera2D
# --- AIM DOWN CINEMATIC OVERRIDE ---
@export var aim_down_zoom := Vector2(1.23, 1.23) # slightly more zoom than lock_zoom
@export var aim_down_zoom_in_time := 0.55
@export var aim_down_zoom_out_time := 0.40
@export var aim_zoom_trans := Tween.TRANS_SINE
@export var aim_zoom_ease_in := Tween.EASE_OUT   # when zooming INTO aim zoom
@export var aim_zoom_ease_out := Tween.EASE_IN_OUT # when returning back

var _aim_zoom_active := false
var _aim_zoom_tween: Tween

var shake_intensity: float = 0.0
var shake_duration: float = 0.0
var shake_decay: float = 10.0

@export var look_ahead_distance := 90.0
@export var look_ahead_speed := 6.0
@export var follow_speed := 1.0
@export var target: Node2D

# --- ROOM LOCK / CINEMATIC ---
var is_room_locked := false
var room_lock_position := Vector2.ZERO

var default_zoom := Vector2.ONE
var lock_zoom := Vector2(0.86, 0.86)  # cinematic zoom in (smaller = more zoom)
var lock_smooth := 0.12               # smaller = snappier, bigger = smoother
var zoom_in_time := 0.45
var zoom_out_time := 0.55

var _cam_tween: Tween
# --- HITSTUN SHAKE (persistent) ---
@export var hitstun_shake_intensity := 10.0

var _hitstun_shake_active := false

func start_hitstun_shake(intensity: float = 10.0) -> void:
	_hitstun_shake_active = true
	hitstun_shake_intensity = intensity

func stop_hitstun_shake() -> void:
	_hitstun_shake_active = false
func set_aim_down_cinematic(active: bool) -> void:
	if _aim_zoom_active == active:
		return

	_aim_zoom_active = active

	_kill_aim_zoom_tween()
	_aim_zoom_tween = create_tween()

	# ✅ smoother curve
	var t := aim_down_zoom_in_time if _aim_zoom_active else aim_down_zoom_out_time
	var ease_type := aim_zoom_ease_in if _aim_zoom_active else aim_zoom_ease_out

	_aim_zoom_tween.set_trans(aim_zoom_trans)
	_aim_zoom_tween.set_ease(ease_type)

	# Decide what zoom we should go to
	var target_zoom: Vector2
	if _aim_zoom_active:
		target_zoom = aim_down_zoom
	else:
		target_zoom = lock_zoom if is_room_locked else default_zoom

	_aim_zoom_tween.tween_property(self, "zoom", target_zoom, t)
func _kill_aim_zoom_tween() -> void:
	if _aim_zoom_tween and _aim_zoom_tween.is_valid():
		_aim_zoom_tween.kill()
	_aim_zoom_tween = null
# --- SCREEN SHAKE ---
func apply_shake(intensity: float = 20.0, duration: float = 0.2):
	shake_intensity = max(shake_intensity, intensity)
	shake_duration = max(shake_duration, duration)


func lock_to_room(pos: Vector2) -> void:
	is_room_locked = true
	room_lock_position = pos

	_kill_cam_tween()
	_cam_tween = create_tween()

	# If aim zoom is active, don't force lock_zoom (aim zoom owns zoom right now)
	if not _aim_zoom_active:
		_cam_tween.tween_property(self, "zoom", lock_zoom, zoom_in_time)

func unlock_room() -> void:
	is_room_locked = false

	_kill_cam_tween()
	_cam_tween = create_tween()

	# If aim zoom is active, don't force default_zoom (aim zoom owns zoom right now)
	if not _aim_zoom_active:
		_cam_tween.tween_property(self, "zoom", default_zoom, zoom_out_time)
# A small cinematic pan (used when last enemy dies)
func victory_pan(pan_offset := Vector2(60, -20), pan_time := 0.35, return_time := 0.45) -> void:
	if not is_room_locked:
		return

	_kill_cam_tween()
	_cam_tween = create_tween()

	var a := room_lock_position + pan_offset
	var b := room_lock_position

	# We pan by temporarily changing the lock position
	_cam_tween.tween_method(func(v): room_lock_position = v, room_lock_position, a, pan_time)
	_cam_tween.tween_method(func(v): room_lock_position = v, room_lock_position, b, return_time)
	await _cam_tween.finished


func _kill_cam_tween() -> void:
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = null


func _process(delta):
	var player := get_parent()
	if player == null:
		return

	# --- FOLLOW TARGET OR ROOM LOCK ---
	if is_room_locked:
		# smooth follow to the room lock point
		global_position = global_position.lerp(room_lock_position, 1.0 - pow(lock_smooth, delta * 60.0))
	else:
		if target:
			global_position = global_position.lerp(
				target.global_position,
				delta * follow_speed
			)

	# --- LOOK AHEAD (disable while locked so it stays centered) ---
	if not is_room_locked:
		var dir: Vector2 = player.last_move_dir.normalized()
		if dir.length() < 0.1:
			dir = Vector2.ZERO

		var target_offset = dir * look_ahead_distance
		position = position.lerp(target_offset, delta * look_ahead_speed)
	else:
		# ease offset back to center
		position = position.lerp(Vector2.ZERO, delta * 10.0)

	# --- SCREEN SHAKE ---
	var shake_offset := Vector2.ZERO

	# 1) time-based shake (your existing apply_shake)
	if shake_duration > 0.0:
		shake_duration -= delta

		shake_offset = Vector2(
			randf_range(-shake_intensity, shake_intensity),
			randf_range(-shake_intensity, shake_intensity)
		)

		shake_intensity = lerp(
			shake_intensity,
			0.0,
			delta * shake_decay
		)

	# 2) persistent hitstun shake (while player is locked)
	if _hitstun_shake_active:
		shake_offset += Vector2(
			randf_range(-hitstun_shake_intensity, hitstun_shake_intensity),
			randf_range(-hitstun_shake_intensity, hitstun_shake_intensity)
		)

	position += shake_offset
