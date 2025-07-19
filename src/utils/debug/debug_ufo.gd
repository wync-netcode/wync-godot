extends Sprite2D

func _process(_delta: float) -> void:
	position.x += 240.0 / Engine.get_frames_per_second()
	
	if position.x > 1500: position.x = 300
