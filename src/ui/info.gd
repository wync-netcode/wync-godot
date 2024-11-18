extends Control

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS
@onready var lblMain: Label = %lblMain
# TODO: Use a service
@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback
@onready var co_prediction_data: CoSingleNetPredictionData = %CoSingleNetPredictionData

func _process(delta):
	lblMain.text = \
	"""
	PhysicsFPS: %s
	ScreenFPS: %s
	Latency: %s
	tick_offset: %s
	""" % \
	[
		Engine.physics_ticks_per_second,
		Performance.get_monitor(Performance.TIME_FPS),
		co_loopback.lag,
		co_prediction_data.tick_offset,
	]
