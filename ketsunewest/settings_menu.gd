extends Control

@onready var music_slider: HSlider = $VBoxContainer/MusicSlider
@onready var sfx_slider: HSlider = $VBoxContainer/SfxSlider

func _ready() -> void:
	# Make sliders match saved settings
	music_slider.value = AudioSettings.music_db
	sfx_slider.value = AudioSettings.sfx_db

	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)

func _on_music_changed(v: float) -> void:
	AudioSettings.music_db = v
	AudioSettings.apply()
	AudioSettings.save_settings()

func _on_sfx_changed(v: float) -> void:
	AudioSettings.sfx_db = v
	AudioSettings.apply()
	AudioSettings.save_settings()

func _on_settings_back_pressed() -> void:
	# optional extra save (already saving on change)
	AudioSettings.save_settings()
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
