extends CharacterBody2D

var speed = 300
var vel : float

func _physics_process(delta):
	
	
	move_local_x(vel * speed * delta)
