extends Node2D

@onready var respawn_point: Marker2D = $Respawn1


func _ready():
	Respawn.set_respawn(respawn_point.global_position)
	Combatmusicmanager.set_combat_music(
		preload("res://audio/music.mp3")
	)

	ShopMusic.set_shop_music(
		preload("res://audio/Shoplifting.mp3")
	)
		# ✅ Main/Exploration music (always wants to play)
	MusicRouter.set_main_music(preload("res://audio/Hollow Knight OST - Waterways.mp3"))
	MusicRouter.play_main(true)
	
	

func _process(delta: float) -> void:
	pass
