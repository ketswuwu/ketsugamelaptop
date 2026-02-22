extends Node

var stats = {
	"max_health": 5,
	"health": 5,
	"attack": 5
}

# Use dictionary to track unlocked status
var abilities = {
	"Double Jump": false,
	"Dash": true,
	"Wall Climb": false
}

var items = {
	"Potion": 3,
	"Key": 1,
	"Pesos": 0
}

func unlock_ability(name: String):
	if abilities.has(name):
		abilities[name] = true
		print("[PlayerData] Unlocked ability:", name)

func lock_ability(name: String):
	if abilities.has(name):
		abilities[name] = false
		print("[PlayerData] Locked ability:", name)
