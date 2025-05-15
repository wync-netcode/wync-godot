extends Node

enum PEER {
	SERVER,
	CLIENT
}
@export var setup_type: PEER = PEER.CLIENT


func _ready():
	if setup_type == PEER.SERVER:
		setup_server()

	elif setup_type == PEER.CLIENT:
		setup_client()


func setup_server():
	var co_wync_ctx = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = co_wync_ctx.ctx

	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	WyncUtils.server_setup(ctx)


func setup_client():
	var co_wync_ctx = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = co_wync_ctx.ctx

	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)

	# set server tick rate and lerp_ms
	var server_tick_rate: int = ctx.physic_ticks_per_second
	var desired_lerp: int = ceil((1000.0 / server_tick_rate) * 6) # 6 ticks in the past
	WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, desired_lerp)
