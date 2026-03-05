extends Node
@export var fade_in_time := 1.0
@export var fade_out_time := 1.0
@onready var music: AudioStreamPlayer = AudioStreamPlayer.new()
@onready var tween: Tween

var is_playing := true
# Called when the node enters the scene tree for the first time.
func _ready():
	add_child(music)
	music.bus = "Music"
	music.volume_db = -80
	music.autoplay = false
	
func set_main_music(stream: AudioStream):
	music.stream = stream
# Called every frame. 'delta' is the elapsed time since the previous frame.
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
func _process(delta: float) -> void:
	pass
