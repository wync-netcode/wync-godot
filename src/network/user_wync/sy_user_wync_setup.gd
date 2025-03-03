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
