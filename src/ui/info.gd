extends Control

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS

func _process(delta):
	lblPhysicsFPS.text = str(Engine.physics_ticks_per_second)
	lblRealFPS.text = str(Performance.get_monitor(Performance.TIME_FPS))
