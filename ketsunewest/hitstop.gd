extends Node

var active := false

func apply(duration := 0.05, strength := 0.05):
	if active:
		return

	active = true
	Engine.time_scale = strength

	await get_tree().create_timer(duration, true).timeout

	Engine.time_scale = 1.0
	active = false
