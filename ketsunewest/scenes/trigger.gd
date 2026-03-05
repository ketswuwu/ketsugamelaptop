extends Area2D

@export var boss_name: String = "Boss"
@export var boss_path: NodePath  # drag your Boss node here in the inspector (recommended)

var _activated := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if _activated:
		return
	if not body.is_in_group("player"):
		return

	_activated = true

	# Find the UI anywhere in the scene tree (works with instanced rooms)
	var boss_ui := get_tree().get_first_node_in_group("boss_ui")
	if boss_ui == null:
		push_warning("No node in group 'boss_ui' found. Add your BossHP UI to group 'boss_ui'.")
		return

	# Get boss
	var boss := get_node_or_null(boss_path)
	if boss == null:
		# fallback: try group lookup if you didn't set boss_path
		boss = get_tree().get_first_node_in_group("boss")
	if boss == null:
		push_warning("Boss not found. Set boss_path on the trigger OR put boss in group 'boss'.")
		return

	# Show bar for boss
	if boss_ui.has_method("show_for_boss"):
		boss_ui.show_for_boss(boss, boss_name)
	else:
		push_warning("Boss UI node doesn't have method show_for_boss(). Did you attach the BossHP script to it?")
