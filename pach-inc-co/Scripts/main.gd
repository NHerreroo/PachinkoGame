extends Node3D

func _ready() -> void:
	Global.time = 120

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Global.time <= 0:
		get_tree().change_scene_to_file("res://Scenes/MachineScene.tscn")
