extends CanvasLayer

@onready var potion: Sprite2D = $Potion
var menu_open: bool = false

func _ready():
	visible = false
func is_open() -> bool:
	return menu_open
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("open_menu"):
		# ✅ don't open inventory if pause menu is open
		var pm := get_tree().get_first_node_in_group("pause_menu_ui")
		if pm and pm.has_method("is_open") and pm.is_open():
			return

		toggle_menu()

func _process(_delta):
	if State.health_potion == "bought":
		potion.visible = true

func toggle_menu():
	menu_open = !menu_open
	visible = menu_open
	get_tree().paused = menu_open
