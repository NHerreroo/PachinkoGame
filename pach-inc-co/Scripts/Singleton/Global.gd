extends Node
 
var time = 30 #2min
var balls = 40

var interval = 2


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		get_tree().quit()
