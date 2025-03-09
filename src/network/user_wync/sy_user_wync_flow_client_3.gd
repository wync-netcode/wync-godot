class_name SyUserWyncFlowClient3
extends System
const label: StringName = StringName("SyUserWyncFlowClient3")

## Runs wync flow functions (tick start, tick end, etc)


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback", Log.TAG_LATENCY)
		return
	
	# let wync know the latency
	WyncFlow.wync_client_set_current_latency (single_wync.ctx, co_loopback.ctx.latency)
	
	WyncThrottle.wync_set_data_limit_chars_for_out_packets(ctx, 50000)

	WyncFlow.wync_client_tick_end(ctx)
