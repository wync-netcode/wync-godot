extends Control

@onready var lblPhysicsFPS: Label = %lblPhysicsFPS
@onready var lblRealFPS: Label = %lblRealFPS
@onready var lblMain: Label = %lblMain
# TODO: Use a service
@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback
@onready var co_wync_ctx_server: CoSingleWyncContext = %"CoSingleWyncContext-Server"
@onready var co_wync_ctx_client: CoSingleWyncContext = %"CoSingleWyncContext-Server"


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
		co_wync_ctx_client.ctx.co_predict_data.latency_stable,
		co_wync_ctx_client.ctx.co_predict_data.tick_offset,
		co_wync_ctx_client.ctx.co_predict_data.lerp_ms,
		co_wync_ctx_server.ctx.co_ticks.ticks,
		co_wync_ctx_server.ctx.delta_base_state_tick
	]
