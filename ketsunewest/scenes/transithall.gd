extends Node2D

@export var room_id: StringName = &"arena_room_new"
@onready var camerapoint: Marker2D = $camerapoint

# -----------------------------------------
# ENEMIES (waves)
# -----------------------------------------
@export var enemy_scene: PackedScene
@export var waves: Array[WaveConfig] = []
@export var wave_pick_mode: String = "cycle"

@export var wave_delay: float = 0.6
@export var spawn_stagger_delay: float = 0.18
@export var enemies_per_wave: Array[int] = [2, 2, 4, 4]

# -----------------------------------------
@onready var playerdetector: Area2D = $PlayerDetector

@onready var spawn1: Marker2D = $spawn1
@onready var spawn2: Marker2D = $spawn2
@onready var spawn3: Marker2D = $spawn3
@onready var spawn4: Marker2D = $spawn4

# -----------------------------------------
# GATES
# -----------------------------------------
@onready var gate_sfx: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
@onready var gate1: StaticBody2D = get_node_or_null("nobackwall")
@onready var gate2: StaticBody2D = get_node_or_null("nobackwall2")
@onready var gate1_anim: AnimatedSprite2D = get_node_or_null("nobackwall/AnimatedSprite2D")
@onready var gate2_anim: AnimatedSprite2D = get_node_or_null("nobackwall2/AnimatedSprite2D")

# -----------------------------------------
# MUSIC (same behavior as BossRoom)
# -----------------------------------------
@export var music_fade_in_time: float = 1.0
@export var music_fade_out_time: float = 1.0
@export var music_volume_db: float = -2.0
@export var music_silent_db: float = -60.0

@onready var music: AudioStreamPlayer = $Music
@onready var arena_bounds: Area2D = get_node_or_null("ArenaBounds") # optional

var _music_tween: Tween
var player_inside_arena := false

# -----------------------------------------
var started := false
var finished := false

var current_wave := 0
var alive_in_wave := 0
var spawning_next_wave := false
var spawned_enemies: Array[Node] = []
var wave_spawn_index := 0


func _ready() -> void:
	playerdetector.body_entered.connect(_on_playerdetector_body_entered)

	# start OPEN
	_set_gate_layer(gate1, 0)
	_set_gate_layer(gate2, 0)

	# --- MUSIC INIT ---
	if music:
		music.autoplay = false
		music.volume_db = music_silent_db

		# Try to force tweexlooping
		if music.stream and music.stream.has_method("set_loop"):
			music.stream.set_loop(true)
		elif music.stream and "loop" in music.stream:
			music.stream.loop = true

	# Optional exit detection
	if arena_bounds:
		arena_bounds.body_entered.connect(_on_arena_bounds_entered)
		arena_bounds.body_exited.connect(_on_arena_bounds_exited)

	if Respawn.is_room_completed(room_id):
		finished = true
		started = true
		playerdetector.monitoring = false


func _process(_delta: float) -> void:
	# Keep music obeying cutscene state
	var in_cutscene := ("in_cutscene" in State and State.in_cutscene == true)

	if player_inside_arena and not in_cutscene and not finished:
		_music_fade_in()
	else:
		_music_fade_out()


func _on_playerdetector_body_entered(body: Node) -> void:
	if finished or started:
		return
	if not body.is_in_group("player"):
		return

	started = true
	Respawn.enter_room(self, room_id)

	# Lock camera to this arena
	var cam := _get_camera(body)
	if cam and cam.has_method("lock_to_room"):
		cam.lock_to_room(camerapoint.global_position)
		if cam.has_method("apply_shake"):
			cam.apply_shake(10.0, 0.18)

	# ✅ CLOSE GATES when fight starts
	_close_gates()

	# ✅ Consider player "inside arena" as soon as they enter
	# (ArenaBounds will keep this accurate when leaving.)
	player_inside_arena = true

	# Start wave 0
	current_wave = 0
	_spawn_wave(current_wave)


func _on_arena_bounds_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside_arena = true


func _on_arena_bounds_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside_arena = false


func _get_camera(from_body: Node) -> Camera2D:
	if from_body and from_body.has_node("Camera2D"):
		var cam := from_body.get_node("Camera2D")
		if cam is Camera2D:
			return cam

	var scene := get_tree().current_scene
	if scene == null:
		return null

	var cam_node := scene.find_child("Camera2D", true, false)
	if cam_node is Camera2D:
		return cam_node

	return null


# -----------------------
# Gate helpers
# -----------------------
func _set_gate_layer(g: StaticBody2D, layer: int) -> void:
	if not is_instance_valid(g):
		return

	g.collision_layer = layer

	var shapes := g.find_children("*", "CollisionShape2D", true, false)
	for s in shapes:
		(s as CollisionShape2D).disabled = false


func _close_gates() -> void:
	_set_gate_layer(gate1, 1)
	_set_gate_layer(gate2, 1)

	if is_instance_valid(gate_sfx):
		gate_sfx.stop()
		gate_sfx.play()

	if is_instance_valid(gate1_anim):
		gate1_anim.play("gate_up")
	if is_instance_valid(gate2_anim):
		gate2_anim.play("gate_up")


func _open_gates() -> void:
	if is_instance_valid(gate_sfx):
		gate_sfx.stop()
		gate_sfx.play()

	if is_instance_valid(gate1_anim):
		gate1_anim.play("gate_down")
	if is_instance_valid(gate2_anim):
		gate2_anim.play("gate_down")

	if is_instance_valid(gate1_anim):
		await gate1_anim.animation_finished
	if is_instance_valid(gate2_anim):
		await gate2_anim.animation_finished

	_set_gate_layer(gate1, 0)
	_set_gate_layer(gate2, 0)


# -----------------------
# MUSIC helpers (same as boss room)
# -----------------------
func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null


func _music_fade_in() -> void:
	if not music or music.stream == null:
		return

	# If not already playing, restart from the beginning then fade in
	if not music.playing:
		music.stop()
		music.volume_db = music_silent_db
		music.play(0.0) # ✅ start from beginning every time

	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", music_volume_db, music_fade_in_time)


func _music_fade_out() -> void:
	if not music:
		return
	if not music.playing:
		return

	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(music, "volume_db", music_silent_db, music_fade_out_time)
	_music_tween.tween_callback(func():
		if music:
			music.stop()
	)


# -----------------------------------------
# Wave helpers
# -----------------------------------------
func _get_wave_scenes(wave_index: int) -> Array[PackedScene]:
	if waves.size() == 0:
		return []
	var idx: int = clamp(wave_index, 0, waves.size() - 1)
	var wc := waves[idx]
	if wc == null:
		return []
	return wc.scenes


func _pick_scene_for_spawn(wave_scenes: Array[PackedScene]) -> PackedScene:
	if wave_scenes.size() == 0:
		return enemy_scene

	var usable: Array[PackedScene] = []
	for s in wave_scenes:
		if s != null:
			usable.append(s)

	if usable.size() == 0:
		return enemy_scene

	if wave_pick_mode == "random":
		return usable[randi_range(0, usable.size() - 1)]

	var picked := usable[wave_spawn_index % usable.size()]
	wave_spawn_index += 1
	return picked


func _spawn_points_for_wave(wave_index: int) -> Array[Marker2D]:
	match wave_index:
		0:
			return [spawn1, spawn2]
		1:
			return [spawn3, spawn4]
		2, 3:
			return [spawn1, spawn2, spawn3, spawn4]
		_:
			return [spawn1, spawn2, spawn3, spawn4]


func _enemies_to_spawn_for_wave(wave_index: int) -> int:
	if wave_index >= 0 and wave_index < enemies_per_wave.size():
		return max(0, enemies_per_wave[wave_index])
	return 4


func _spawn_wave(wave_index: int) -> void:
	spawning_next_wave = false
	alive_in_wave = 0
	wave_spawn_index = 0

	var spawn_points := _spawn_points_for_wave(wave_index)
	var to_spawn := _enemies_to_spawn_for_wave(wave_index)
	var wave_scenes := _get_wave_scenes(wave_index)

	if to_spawn <= 0:
		_next_wave_or_finish()
		return

	for i in range(to_spawn):
		var sp := spawn_points[i % spawn_points.size()]

		var scene_to_spawn := _pick_scene_for_spawn(wave_scenes)
		if scene_to_spawn == null:
			push_error("No enemy scene available for wave %d. Set enemy_scene or add scenes to this wave." % wave_index)
			return

		var enemy := scene_to_spawn.instantiate()
		add_child(enemy)
		enemy.global_position = sp.global_position

		spawned_enemies.append(enemy)
		enemy.add_to_group("room_enemy")

		var player := get_tree().current_scene.find_child("Player", true, false)
		var cam := _get_camera(player)
		if cam and cam.has_method("apply_shake"):
			cam.apply_shake(10.0, 0.08)

		alive_in_wave += 1

		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		else:
			push_warning("Spawned enemy has no 'died' signal. Room won't progress on kill.")

		if i < to_spawn - 1:
			await get_tree().create_timer(spawn_stagger_delay).timeout


func _on_enemy_died(_enemy) -> void:
	alive_in_wave = max(0, alive_in_wave - 1)

	if alive_in_wave == 0:
		if spawning_next_wave:
			return
		spawning_next_wave = true
		await get_tree().create_timer(wave_delay).timeout
		_next_wave_or_finish()


func _next_wave_or_finish() -> void:
	current_wave += 1
	var waves_count: int = max(waves.size(), enemies_per_wave.size())

	if current_wave < waves_count:
		_spawn_wave(current_wave)
	else:
		await _finish_room()


func _finish_room() -> void:
	finished = true
	Respawn.mark_room_completed(room_id)
	playerdetector.monitoring = false

	# ✅ stop music once finished (fade out)
	player_inside_arena = false
	_music_fade_out()

	var player := get_tree().current_scene.find_child("Player", true, false)
	var cam := _get_camera(player)

	if cam and cam.has_method("victory_pan"):
		await cam.victory_pan(Vector2(70, -25), 0.30, 0.45)

	await _open_gates()

	if cam and cam.has_method("unlock_room"):
		cam.unlock_room()


func reset_room() -> void:
	var player := get_tree().current_scene.find_child("Player", true, false)
	var cam := _get_camera(player)
	if cam and cam.has_method("unlock_room"):
		cam.unlock_room()

	for e in spawned_enemies:
		if is_instance_valid(e):
			e.queue_free()
	spawned_enemies.clear()

	started = false
	finished = false
	current_wave = 0
	alive_in_wave = 0
	spawning_next_wave = false
	wave_spawn_index = 0

	# ✅ Fade out music immediately on reset/death
	player_inside_arena = false
	_music_fade_out()

	_set_gate_layer(gate1, 0)
	_set_gate_layer(gate2, 0)
	if is_instance_valid(gate1_anim):
		gate1_anim.play("gate_down")
	if is_instance_valid(gate2_anim):
		gate2_anim.play("gate_down")

	playerdetector.monitoring = true
