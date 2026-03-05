extends Node

const SAVE_PATH := "user://audio_settings.cfg"

var music_db: float = -18.0
var sfx_db: float = -12.0

func _ready() -> void:
	load_settings()
	apply()

func apply() -> void:
	var music_bus := AudioServer.get_bus_index("Music")
	var sfx_bus := AudioServer.get_bus_index("Sfx")

	if music_bus != -1:
		AudioServer.set_bus_volume_db(music_bus, music_db)
		AudioServer.set_bus_mute(music_bus, music_db <= -59.9)

	if sfx_bus != -1:
		AudioServer.set_bus_volume_db(sfx_bus, sfx_db)
		AudioServer.set_bus_mute(sfx_bus, sfx_db <= -59.9)

func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music_db", music_db)
	cfg.set_value("audio", "sfx_db", sfx_db)
	cfg.save(SAVE_PATH)

func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		music_db = float(cfg.get_value("audio", "music_db", music_db))
		sfx_db = float(cfg.get_value("audio", "sfx_db", sfx_db))
