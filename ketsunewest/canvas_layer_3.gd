extends CanvasLayer

@onready var panel := $TextureRect

@export var dialogue_resource: DialogueResource
@export var dialogue_start: String = "start"
@export var end_scene_path: String = "res://scenes/endscreen.tscn"

var is_transitioning := false
var boss_dialogue_running := false

func _ready() -> void:
	panel.modulate.a = 0.0
	visible = false

	# Listen for dialogue finishing
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_ended):
		DialogueManager.dialogue_ended.connect(_on_dialogue_ended)

func _process(_delta: float) -> void:
	if is_transitioning:
		return

	# Only open once when boss is dead
	if ("boss" in State) and State.boss == "dead" and not boss_dialogue_running and not visible:
		open_boss_death()

func open_boss_death() -> void:
	is_transitioning = true

	# Fade to black
	await Fade.fade_out(0.6)

	# Show boss-death overlay (optional)
	visible = true
	panel.modulate.a = 0.0
	var t := create_tween()
	t.tween_property(panel, "modulate:a", 1.0, 0.35)
	await t.finished

	# Fade world back in (still showing overlay)
	await Fade.fade_in(0.6)

	# Start boss death dialogue
	boss_dialogue_running = true
	DialogueManager.show_dialogue_balloon(dialogue_resource, dialogue_start)

	is_transitioning = false

func _on_dialogue_ended(_resource: DialogueResource) -> void:
	# Ignore other dialogues; only react to the boss-death one we started
	if not boss_dialogue_running:
		return

	# Optional extra safety: only react if it ended from THIS resource
	if _resource != dialogue_resource:
		return

	boss_dialogue_running = false
	_go_to_endscreen()

func _go_to_endscreen() -> void:
	if is_transitioning:
		return
	is_transitioning = true

	# Fade out to black
	await Fade.fade_out(0.8)

	# Switch scene while black
	get_tree().change_scene_to_file(end_scene_path)

	# Fade in on the endscreen
	await Fade.fade_in(0.8)

	is_transitioning = false
