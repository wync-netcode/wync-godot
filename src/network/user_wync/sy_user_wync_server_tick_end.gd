class_name SyUserWyncServerTickEnd
extends System
const label: StringName = StringName("SyUserWyncServerTickEnd")

## Runs wync flow functions (tick start, tick end, etc)


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	# set latency
	WyncFlow.wync_client_set_current_latency(ctx, co_loopback.ctx.latency)
	# TODO: set current time
	#WyncFlow.wync_client_set_current_time_ms(ctx, my_game_time)

	# tick end
	WyncFlow.wync_server_tick_end(ctx)
