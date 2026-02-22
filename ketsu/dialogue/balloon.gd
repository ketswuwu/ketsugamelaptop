extends DialogueManagerExampleBalloon
@onready var talk_sound: AudioStreamPlayer = $Talksoundfinal


func _on_dialogue_label_spoke(letter: String, letter_index: int, speed: float) -> void:
	if not letter in ["."," "]:
		talk_sound.pitch_scale = randf_range(0.9, 1.1)
		talk_sound.volume_db = -12
		talk_sound.play()
