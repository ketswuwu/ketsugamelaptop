extends CanvasLayer

@onready var panel := $TextureRect

var is_transitioning := false

func _ready():
	panel.modulate.a = 0.0


func _process(_delta):
	if is_transitioning:
		return

	if State.in_boss == "true" and not visible:
		open_boss_cutscene()
	elif State.in_boss != "true" and visible:
		close_boss_cutscene()


func open_boss_cutscene() -> void:
	is_transitioning = true

	# 1. Fade world to black
	await Fade.fade_out(0.4)

	# 2. Show shop but invisible
	visible = true
	panel.modulate.a = 0.0

	# 3. Fade shop UI in (while screen is black)
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.25)
	await t.finished

	# 4. Fade world back in
	await Fade.fade_in(0.4)

	is_transitioning = false


func close_boss_cutscene() -> void:
	is_transitioning = true

	# 1. Fade world to black
	await Fade.fade_out(0.4)

	# 2. Fade shop out while black
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 0.0, 0.2)
	await t.finished

	visible = false

	# 3. Fade world back in
	await Fade.fade_in(0.4)

	is_transitioning = false
