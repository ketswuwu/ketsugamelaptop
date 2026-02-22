extends Control

@onready var player_stats: Label = $PanelContainer/VBoxContainer/PlayerStats
@onready var abilities: Label = $PanelContainer/VBoxContainer/Abilities
@onready var items: Label = $PanelContainer/VBoxContainer/Items

var menu_open: bool = false

func _ready():
	visible = false  # Start hidden
	update_menu()

func _process(_delta):
	if Input.is_action_just_pressed("open_menu"):
		toggle_menu()

func toggle_menu():
	menu_open = !menu_open
	visible = menu_open

	if menu_open:
		# Pause the game
		get_tree().paused = true
		update_menu()
	else:
		# Unpause the game
		get_tree().paused = false

func update_menu():
	player_stats.text = "Health: %d\nAttack: %d" % [
		Playerdata.stats["health"],
		Playerdata.stats["attack"]
	]

	# Filter only unlocked abilities
	var unlocked_abilities = []
	for ability_name in Playerdata.abilities.keys():
		if Playerdata.abilities[ability_name]:
			unlocked_abilities.append(ability_name)

	if unlocked_abilities.is_empty():
		abilities.text = "Unlocked Abilities:\n- None"
	else:
		abilities.text = "Unlocked Abilities:\n- " + "\n- ".join(unlocked_abilities)

	var item_list = ""
	for item_name in Playerdata.items.keys():
		item_list += "%s x%d\n" % [item_name, Playerdata.items[item_name]]
	items.text = "Items:\n" + item_list
