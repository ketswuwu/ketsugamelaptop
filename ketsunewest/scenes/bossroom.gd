extends Node2D

@export var room_id: StringName = &"boss_room"

@export var boss_name: String = "Boss"
@export var boss_path: NodePath

@export var respawn_marker_name: StringName = &"Respawn2" # in MAIN GAME scene

# Gate settings (edit if your layers differ)
@export var gate_closed_layer: int = 1
@export var gate_open_layer: int = 0

# --- MUSIC SETTINGS ---
@export var music_fade_in_time: float = 1.0
@export var music_fade_out_time: float = 1.0
@export var music_volume_db: float = -0.5  # target volume when fully playing
@export var music_silent_db: float = -60.0 # "silent" volume

@onready var trigger: Area2D = $trigger
@onready var camera_point: Marker2D = $camerapoint

# ✅ Direct gate reference (your node is named "gagte")
@onready var gate: StaticBody2D = $gagte

# ✅ Music player (create this node in the BossRoom scene)
@onready var boss_music: AudioStreamPlayer = get_node_or_null("Music")

# ✅ Optional arena bounds (create Area2D named ArenaBounds to detect leaving)
@onready var arena_bounds: Area2D = get_node_or_null("ArenaBounds")

var started := false
var player_inside_arena := false
var _music_tween: Tween

func _ready() -> void:
	trigger.body_entered.connect(_on_trigger_body_entered)

	# ✅ Safety: when the room scene loads, keep gate OPEN by default
	_open_gate()

	# --- MUSIC INIT ---
	if boss_music:
		boss_music.add_to_group("override_music")
		boss_music.autoplay = false
		boss_music.volume_db = music_silent_db

		# Try to force looping (works for many stream types)
		if boss_music.stream and boss_music.stream.has_method("set_loop"):
			boss_music.stream.set_loop(true)
		elif boss_music.stream and "loop" in boss_music.stream:
			boss_music.stream.loop = true

	# Optional exit detection
	if arena_bounds:
		arena_bounds.body_entered.connect(_on_arena_bounds_entered)
		arena_bounds.body_exited.connect(_on_arena_bounds_exited)

func _process(_delta: float) -> void:
	# Keep music obeying cutscene state
	var in_cutscene := ("in_cutscene" in State and State.in_cutscene == true)

	if player_inside_arena and not in_cutscene:
		_music_fade_in()
	else:
		_music_fade_out()

func _on_trigger_body_entered(body: Node) -> void:
	if started:
		return
	if not body.is_in_group("player"):
		return

	Respawn.in_boss_room = true

	started = true
	trigger.monitoring = false

	Respawn.enter_room(self, room_id)

	# ✅ Update respawn to Respawn2 in MAIN GAME scene
	var rp := get_tree().current_scene.find_child(String(respawn_marker_name), true, false)
	if rp and rp is Node2D:
		Respawn.set_respawn((rp as Node2D).global_position)
	else:
		push_warning("BossRoom: couldn't find respawn marker '%s' in main scene." % respawn_marker_name)

	# ✅ Lock camera
	var cam := _get_camera(body)
	if cam and cam.has_method("lock_to_room"):
		cam.lock_to_room(camera_point.global_position)

	# ✅ Close gate behind player (DIRECT)
	_close_gate()

	# ✅ Show boss UI
	_show_boss_ui()

	# ✅ Consider player "inside arena" as soon as they enter
	# (If you use ArenaBounds, it will keep this accurate when leaving.)
	player_inside_arena = true

func _on_arena_bounds_entered(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside_arena = true

func _on_arena_bounds_exited(body: Node) -> void:
	if body.is_in_group("player"):
		player_inside_arena = false

# -----------------------
# Gate control (DIRECT)
# -----------------------
func _close_gate() -> void:
	if not is_instance_valid(gate):
		push_warning("BossRoom: gate node 'gagte' not found.")
		return
	gate.collision_layer = gate_closed_layer

func _open_gate() -> void:
	if not is_instance_valid(gate):
		return
	gate.collision_layer = gate_open_layer

# -----------------------
# MUSIC helpers
# -----------------------
func _kill_music_tween() -> void:
	if _music_tween and _music_tween.is_valid():
		_music_tween.kill()
	_music_tween = null

func _music_fade_in() -> void:
	if not boss_music or boss_music.stream == null:
		return

	# If not already playing, restart from the beginning then fade in
	if not boss_music.playing:
		boss_music.stop()          # ensure it isn't resuming
		boss_music.volume_db = music_silent_db
		boss_music.play(0.0)       # ✅ start from the beginning

	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(boss_music, "volume_db", music_volume_db, music_fade_in_time)
	
func _music_fade_out() -> void:
	if not boss_music:
		return
	if not boss_music.playing:
		return

	_kill_music_tween()
	_music_tween = create_tween()
	_music_tween.tween_property(boss_music, "volume_db", music_silent_db, music_fade_out_time)
	_music_tween.tween_callback(func():
		if boss_music:
			boss_music.stop()
			# boss_music.playback_position = 0.0  # (not needed if using play(0.0))
	)

# -----------------------
# Boss UI
# -----------------------
func _show_boss_ui() -> void:
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui == null:
		push_warning("BossRoom: no node in group 'boss_ui' found.")
		return

	var boss := get_node_or_null(boss_path)
	if boss == null:
		boss = get_tree().get_first_node_in_group("boss")

	if boss == null:
		push_warning("BossRoom: boss not found (set boss_path or put boss in group 'boss').")
		return

	if boss_ui.has_method("show_for_boss"):
		boss_ui.show_for_boss(boss, boss_name)
	elif boss_ui is CanvasItem:
		(boss_ui as CanvasItem).visible = true

func _hide_boss_ui() -> void:
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui == null:
		return

	if boss_ui.has_method("hide_boss"):
		boss_ui.hide_boss()
	elif boss_ui is CanvasItem:
		(boss_ui as CanvasItem).visible = false

# -----------------------
# Respawn hook
# -----------------------
func reset_room() -> void:
	Respawn.in_boss_room = false

	# ✅ Open gate so player can re-enter
	_open_gate()

	# ✅ Hide UI on death
	_hide_boss_ui()

	# ✅ Fade out music immediately on death reset
	player_inside_arena = false
	_music_fade_out()

	# ✅ Allow the trigger to fire again on re-entry
	started = false
	trigger.monitoring = true

	# ✅ Boss reset (redundant-safe)
	var boss := get_node_or_null(boss_path)
	if boss == null:
		boss = get_tree().get_first_node_in_group("boss")

	if boss and boss.has_method("reset_on_respawn"):
		boss.reset_on_respawn()

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
