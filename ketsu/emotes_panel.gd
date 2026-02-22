extends Panel

@onready var animated_sprite_2d: AnimatedSprite2D = $AnimatedSprite2d

var talk: Array = ["talk"]

func _ready() -> void:
	animated_sprite_2d.play("talk")
	
func play_emote(animation: String) -> void:
	animated_sprite_2d.play(animation)
