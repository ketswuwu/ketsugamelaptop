extends Area2D

@export var dialogue_resource: DialogueResource
@export var start_node := "start"

var triggered := false

func _ready():
	add_to_group("respawn_reset") # ✅ any name is fine, just match Respawn
	body_entered.connect(_on_body_entered)

func _on_body_entered(body):
	if triggered:
		return

	if body.is_in_group("player"):
		triggered = true
		DialogueManager.show_dialogue_balloon(dialogue_resource, start_node)

func reset_on_respawn() -> void:
	triggered = false
	monitoring = true # ✅ makes sure it can fire again
