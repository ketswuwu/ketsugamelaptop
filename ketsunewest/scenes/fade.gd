extends CanvasLayer

@onready var rect: ColorRect = $ColorRect

func _ready():
	rect.modulate.a = 0
	hide()

func fade_out(time := 0.4) -> void:
	show()
	var t = create_tween()
	t.tween_property(rect, "modulate:a", 1.0, time)
	await t.finished

func fade_in(time := 0.4) -> void:
	var t = create_tween()
	t.tween_property(rect, "modulate:a", 0.0, time)
	await t.finished
	hide()
