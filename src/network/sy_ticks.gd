extends System
class_name SyTicks
const label: StringName = StringName("SyTicks")


func on_process(_entities, _data, _delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_ticks = wync_ctx.co_ticks
	if co_ticks:
		co_ticks.ticks += 1
		co_ticks.server_ticks += 1
		co_ticks.lerp_delta_accumulator_ms = 0
