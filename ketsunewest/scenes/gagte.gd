extends StaticBody2D

@export var closed_layer: int = 1
@export var open_layer: int = 0

@onready var _shapes: Array[CollisionShape2D] = []

func _ready() -> void:
	_shapes = []
	for n in find_children("*", "CollisionShape2D", true, false):
		_shapes.append(n as CollisionShape2D)

func _on_trigger_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		close_gate()

func close_gate() -> void:
	collision_layer = closed_layer
	for s in _shapes:
		if is_instance_valid(s):
			s.disabled = false
	print("Gate closed (layer=%s, shapes=%s)" % [collision_layer, _shapes.size()])

func open_gate() -> void:
	collision_layer = open_layer
	for s in _shapes:
		if is_instance_valid(s):
			s.disabled = true
	print("Gate opened (layer=%s, shapes=%s)" % [collision_layer, _shapes.size()])
