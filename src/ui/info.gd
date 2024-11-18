extends Control

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS
@onready var lblMain: Label = %lblMain
@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback

func _process(delta):
	lblMain.text = \
	"""
	PhysicsFPS: %s
	ScreenFPS: %s
	Latency: %s
	""" % \
	[
		Engine.physics_ticks_per_second,
		Performance.get_monitor(Performance.TIME_FPS),
		co_loopback.lag
	]
