extends Control

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS
@onready var lblMain: Label = %lblMain
# TODO: Use a service
@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback
@onready var co_prediction_data: CoSingleNetPredictionData = %CoSingleNetPredictionData
@onready var co_wync_ctx: CoSingleWyncContext = %CoSingleWyncContext


func _process(_delta):
	lblMain.text = \
	"""PhysicsFPS: %s
	ScreenFPS: %s
	Latency: %s
	Latency_stable: %s
	tick_offset: %s
	lerp_ms: %s
	server_tick: %s
	delta_base_tick: %s
	""" % \
	[
		Engine.physics_ticks_per_second,
		Performance.get_monitor(Performance.TIME_FPS),
		co_loopback.latency,
		co_prediction_data.latency_stable,
		co_prediction_data.tick_offset,
		co_prediction_data.lerp_ms,
		co_wync_ctx.ctx.co_ticks.ticks,
		co_wync_ctx.ctx.delta_base_state_tick
	]
