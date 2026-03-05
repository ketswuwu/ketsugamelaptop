extends Node

# Main/exploration music volumes
@export var main_volume_db: float = 14.0
@export var silent_db: float = -60.0
@export var fade_in_time: float = 2.0
@export var fade_out_time: float = 2.0

# Any AudioStreamPlayer that should override the main music goes in this group:
const OVERRIDE_GROUP := "override_music"

var _player: AudioStreamPlayer
var _tween: Tween
var _is_ducked := false

func _ready() -> void:
	# Create the main music player once and keep it across scenes.
	_player = AudioStreamPlayer.new()
	_player.name = "MainMusic"
	_player.autoplay = false
	_player.volume_db = silent_db
	add_child(_player)
	process_mode = Node.PROCESS_MODE_ALWAYS


func set_main_music(stream: AudioStream) -> void:
	_player.stream = stream


func play_main(from_start := true) -> void:
	if _player.stream == null:
		push_warning("MusicRouter: main stream is null. Call set_main_music() first.")
		return

	if from_start:
		_player.stop()
		_player.volume_db = silent_db
		_player.play(0.0)
	else:
		if not _player.playing:
			_player.play()

	# Fade in unless currently ducked
	if not _should_duck():
		_fade_to(main_volume_db, fade_in_time)


func stop_main() -> void:
	_fade_to(silent_db, fade_out_time)
	if _player:
		_player.stop()


func _process(_delta: float) -> void:
	var duck := _should_duck()

	# Only react on changes (prevents restarting tweens every frame)
	if duck and not _is_ducked:
		_is_ducked = true
		_fade_to(silent_db, fade_out_time)

	elif not duck and _is_ducked:
		_is_ducked = false

		# Ensure main is playing (so it can fade back in)
		if _player and _player.stream and not _player.playing:
			_player.volume_db = silent_db
			_player.play(0.0)

		_fade_to(main_volume_db, fade_in_time)


func _should_duck() -> bool:
	# 1) Duck during cutscenes
	if "in_cutscene" in State and State.in_cutscene == true:
		return true

	# 2) Duck if any override music is playing
	var overrides := get_tree().get_nodes_in_group(OVERRIDE_GROUP)
	for n in overrides:
		if n == null:
			continue
		if n is AudioStreamPlayer:
			var p := n as AudioStreamPlayer
			if p.playing and p.volume_db > silent_db + 1.0:
				return true
		elif n.has_method("is_music_playing"):
			# optional hook if you have a manager node
			if n.is_music_playing():
				return true

	return false


func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null


func _fade_to(db: float, t: float) -> void:
	if not _player:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.tween_property(_player, "volume_db", db, max(0.01, t))
