extends Area2D

@export var end_scene_path: String = "res://scenes/endscreen.tscn"
@export var boss_node_path: NodePath  # drag your Boss node here in the inspector (recommended)

@onready var col: CollisionShape2D = get_node_or_null("CollisionShape2D")

var _unlocked := false

func _ready() -> void:
	# Start LOCKED
	_set_unlocked(false)

	# Find boss (either via exported path OR group "boss")
	var boss := _get_boss()
	if boss:
		# Connect to signal once
		if boss.has_signal("boss_died"):
			if not boss.boss_died.is_connected(_on_boss_died):
				boss.boss_died.connect(_on_boss_died)
		else:
			push_warning("ExitTrigger: Boss has no signal 'boss_died'.")
	else:
		push_warning("ExitTrigger: Boss not found. Assign boss_node_path or put boss in group 'boss'.")

	body_entered.connect(_on_body_entered)

func _get_boss() -> Node:
	if boss_node_path != NodePath("") and has_node(boss_node_path):
		return get_node(boss_node_path)

	# fallback: by group (add boss to group "boss" in the editor)
	return get_tree().get_first_node_in_group("boss")

func _set_unlocked(value: bool) -> void:
	_unlocked = value
	monitoring = value
	monitorable = value
	if col:
		col.disabled = not value

	# Optional: hide it until unlocked (comment out if you want it visible)
	visible = value

func _on_boss_died() -> void:
	_set_unlocked(true)

func _on_body_entered(body: Node) -> void:
	if not _unlocked:
		return
	if body.is_in_group("player"):
		get_tree().change_scene_to_file(end_scene_path)
