extends Control

var is_open: bool = false

@onready var stats_label = $PanelContainer/VBoxContainer/StatsLabel
@onready var abilities_label = $PanelContainer/VBoxContainer/AbilitiesLabel
@onready var items_label = $PanelContainer/VBoxContainer/ItemsLabel

func _ready():
	# Start closed
	visible = false
	set_process_input(true)

func open_menu():
	is_open = true
	visible = true
	_update_info()
	get_tree().paused = true  # optional: pause game

func close_menu():
	is_open = false
	visible = false
	get_tree().paused = false  # unpause game

func toggle_menu():
	if is_open:
		close_menu()
	else:
		open_menu()

# ✅ Detects input even when UI is focused
func _unhandled_input(event):
	if event.is_action_pressed("open_menu") or event.is_action_pressed("ui_cancel"):
		toggle_menu()
		get_viewport().set_input_as_handled()

func _update_info():
	if stats_label:
		stats_label.text = "Health: 100\nMana: 50\nLevel: 5"
	if abilities_label:
		abilities_label.text = "Abilities:\n- Fireball\n- Dash"
	if items_label:
		items_label.text = "Items:\n- Sword\n- Potion"
