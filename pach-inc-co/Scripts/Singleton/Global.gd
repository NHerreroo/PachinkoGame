extends Node
 
var time = 120 #2min
var balls = 1000



func _input(event: InputEvent) -> void:
	if event.is_action_pressed("Menu"):
		get_tree().quit()
