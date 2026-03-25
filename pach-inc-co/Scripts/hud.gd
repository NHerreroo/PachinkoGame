extends Control

func _ready():
	var timer = Timer.new()
	timer.wait_time = 1.0
	timer.timeout.connect(_on_timer_timeout)
	timer.autostart = true
	add_child(timer)

func _process(delta: float) -> void:
	$CanvasLayer/Time.text = str(Global.time)
	$CanvasLayer/Bolas.text = str(Global.balls)

func _on_timer_timeout():
	if Global.time > 0:
		Global.time -= 1
