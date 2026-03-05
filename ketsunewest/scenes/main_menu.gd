extends Control

@onready var start_sound: AudioStreamPlayer2D = $StartSound

func _on_start_pressed() -> void:

	get_tree().change_scene_to_file("res://scenes/cutscenes.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/settings_menu.tscn")

func _on_exit_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/exit.tscn")
