extends Node2D
# --- music ---
@export var music_fade_in_time: float = 3.0
@export var music_fade_out_time: float = 3.0
@export var music_volume_db: float = 16.0
@export var music_silent_db: float = -60.0

@onready var music: AudioStreamPlayer = $Music

var _music_tween: Tween
var _music_should_play := false

@export var room_id: StringName = &"tutorial_room_01" # UNIQUE per room scene
@export var enemy_scene: PackedScene
@export var wave_delay: float = 0.6
@export var spawn_stagger_delay: float = 0.12

@onready var camerapoint: Marker2D = $camerapoint
@onready var respawn_point: Marker2D = $respawn_point
@onready var playerdetector: Area2D = $playerdetector

@onready var spawn1: Marker2D = $spawn1
@onready var spawn2: Marker2D = $spawn2
@onready var spawn3: Marker2D = $spawn3
@onready var gate1: StaticBody2D = $nobackwall
@onready var gate2: StaticBody2D = $nobackwall2

# ✅ FINISH DIALOGUE SETTINGS
@export var finish_dialogue: DialogueResource 
@export var finish_dialogue_start: String = "start"

var started: bool = false
var finished: bool = false
var wave_index: int = 0
var alive_in_wave: int = 0
var spawning_next_wave: bool = false

var spawned_enemies: Array[Node] = []

func _ready() -> void:
	# --- MUSIC INIT ---
	if music:
		music.add_to_group("override_music")
		music.autoplay = false
		music.volume_db = music_silent_db

	# force looping
		if music.stream and music.stream.has_method("set_loop"):
			music.stream.set_loop(true)
		elif music.stream and "loop" in music.stream:
			music.stream.loop = true
	_set_gate_layer(gate1, 0)
	_set_gate_layer(gate2, 0)
	playerdetector.body_entered.connect(_on_playerdetector_body_entered)

	if Respawn.is_room_completed(room_id):
		finished = true
		started = true
		playerdetector.monitoring = false

func _set_gate_layer(g: StaticBody2D, layer: int) -> void:
	if not is_instance_valid(g):
		return
	g.collision_layer = layer
	var shapes := g.find_children("*", "CollisionShape2D", true, false)
	for s in shapes:
		(s as CollisionShape2D).disabled = false

func _open_gates() -> void:
	_set_gate_layer(gate1, 0)
	_set_gate_layer(gate2, 0)

func _close_gates() -> void:
	_set_gate_layer(gate1, 1)
	_set_gate_layer(gate2, 1)

func _on_playerdetector_body_entered(body: Node) -> void:
	if finished or started:
		return
	if not body.is_in_group("player"):
		return

	Respawn.enter_room(self, room_id)

	started = true
	playerdetector.monitoring = false

	var cam := _get_camera(body)
	if cam and cam.has_method("lock_to_room"):
		cam.lock_to_room(camerapoint.global_position)
	_music_should_play = true
	
	await _close_gates()
	await _start_next_wave()

func _start_next_wave() -> void:
	if finished:
		return
	if enemy_scene == null:
		push_error("enemy_scene is not set on the tutorial room!")
		return

	spawning_next_wave = false
	alive_in_wave = 0

	var points: Array[Marker2D] = []

	if wave_index == 0:
		points = [spawn1]
	elif wave_index == 1:
		points = [spawn1, spawn2, spawn3]
	else:
		await _finish_room()
		return

	for i in range(points.size()):
		var sp: Marker2D = points[i]

		var enemy := enemy_scene.instantiate()
		add_child(enemy)
		enemy.global_position = sp.global_position

		spawned_enemies.append(enemy)
		if enemy.has_method("add_to_group"):
			enemy.add_to_group("room_enemy")

		alive_in_wave += 1

		if enemy.has_signal("died"):
			enemy.died.connect(_on_enemy_died)
		else:
			push_warning("Enemy scene has no 'died' signal. Waves won't progress!")

		if i < points.size() - 1:
			await get_tree().create_timer(spawn_stagger_delay).timeout
func _process(_delta: float) -> void:
	if _music_should_play:
		_music_fade_in()
	else:
		_music_fade_out()
		
func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

func _music_fade_in() -> void:
	if not music or music.stream == null:
		return

	# restart from beginning when starting
	if not music.playing:
		music.stop()
		music.volume_db = music_silent_db
		music.play(0.0)

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
		
func _on_enemy_died(_enemy) -> void:
	alive_in_wave = max(0, alive_in_wave - 1)

	if alive_in_wave == 0:
		if spawning_next_wave:
			return
		spawning_next_wave = true

		wave_index += 1
		await get_tree().create_timer(wave_delay).timeout
		await _start_next_wave()

func _finish_room() -> void:
	finished = true
	Respawn.mark_room_completed(room_id)

	var player := get_tree().current_scene.find_child("Player", true, false)
	var cam := _get_camera(player)
	_music_should_play = false
	_music_fade_out()
	await _open_gates()

	if cam and cam.has_method("unlock_room"):
		cam.unlock_room()

	# ✅ START DIALOGUE AFTER FINISH
	if finish_dialogue != null:
		# optional: lock player movement during dialogue if you use this pattern
		if "player_can_move" in State:
			State.player_can_move = false

		DialogueManager.show_dialogue_balloon(finish_dialogue, finish_dialogue_start)

func reset_room() -> void:
	_music_should_play = false
	_music_fade_out()
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
	wave_index = 0
	alive_in_wave = 0
	spawning_next_wave = false

	playerdetector.monitoring = true

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
