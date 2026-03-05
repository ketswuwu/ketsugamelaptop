extends CanvasLayer

@onready var fade_rect: ColorRect = $FadeRect
var _tween: Tween

func _ready() -> void:
	# Ensure it starts transparent
	if fade_rect:
		var c := fade_rect.color
		c.a = 0.0
		fade_rect.color = c
		fade_rect.visible = true

func _kill_tween() -> void:
	if _tween and _tween.is_valid():
		_tween.kill()
	_tween = null

func fade_out(time: float = 1.0) -> void:
	if fade_rect == null:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(fade_rect, "color:a", 1.0, time)
	await _tween.finished

func fade_in(time: float = 1.0) -> void:
	if fade_rect == null:
		return
	_kill_tween()
	_tween = create_tween()
	_tween.set_trans(Tween.TRANS_SINE)
	_tween.set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(fade_rect, "color:a", 0.0, time)
	await _tween.finished
