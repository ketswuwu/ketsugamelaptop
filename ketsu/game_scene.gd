extends Node2D


func _ready():
	Combatmusicmanager.set_combat_music(
		preload("res://audio/music.mp3")
	)

	ShopMusic.set_shop_music(
		preload("res://audio/Shoplifting.mp3")
	)
	MainMusic.set_main_music(
		preload("res://audio/Dead Cells - Prisoner's Awakening (Official Soundtrack).mp3")
	)
	


func _process(delta: float) -> void:
	pass
