extends Node

@export var fade_time := 1.2
@export var fade_in_time := 1.2
@export var fade_out_time := 3.0   # ← longer fade-out

var enemies_in_combat := 0
var is_playing := false

@onready var music: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var tween: Tween

func _ready():
	add_child(music)
	music.bus = "Music"
	music.volume_db = -80
	music.autoplay = false

func set_combat_music(stream: AudioStream):
	music.stream = stream

func enemy_started_combat():
	enemies_in_combat += 1

	if enemies_in_combat == 1:
		_play_music()

func enemy_stopped_combat():
	enemies_in_combat = max(0, enemies_in_combat - 1)

	if enemies_in_combat == 0:
		_fade_out()
		
func _play_music():
	if State.in_shop == "true":
		return

	if is_playing or music.stream == null:
		return

	is_playing = true
	music.play()

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", 0, fade_in_time)
func _fade_out():
	if not is_playing:
		return

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", -80, fade_out_time)
	tween.finished.connect(func():
		music.stop()
		is_playing = false
	)
