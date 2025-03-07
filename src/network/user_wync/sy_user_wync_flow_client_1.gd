class_name SyUserWyncFlowClient1
extends System
const label: StringName = StringName("SyUserWyncFlowClient1")

## Runs wync flow functions (tick start, tick end, etc)


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	
	WyncThrottle.wync_set_data_limit_chars_for_out_packets(ctx, 5000)

	WyncFlow.wync_client_tick_start(ctx)
