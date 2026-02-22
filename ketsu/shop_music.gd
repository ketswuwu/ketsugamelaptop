extends Node

@export var fade_in_time := 1.0
@export var fade_out_time := 1.0

@onready var music: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var tween: Tween

var is_playing := false
var last_in_shop := false


func _ready():
	add_child(music)
	music.bus = "Music"
	music.volume_db = -80
	music.autoplay = false


func set_shop_music(stream: AudioStream):
	music.stream = stream


func _process(_delta):
	var now_in_shop := State.in_shop == "true"

	if now_in_shop != last_in_shop:
		if now_in_shop:
			_play()
		else:
			_fade_out()

	last_in_shop = now_in_shop


func _play():
	if is_playing or music.stream == null:
		return

	is_playing = true
	music.play()

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", 0.0, fade_in_time)


func _fade_out():
	if not is_playing:
		return

	if tween:
		tween.kill()

	tween = create_tween()
	tween.tween_property(music, "volume_db", -80.0, fade_out_time)
	tween.finished.connect(func():
		music.stop()
		is_playing = false
	)
