extends System
class_name SyTicks
const label: StringName = StringName("SyTicks")


func on_process(_entities, _data, _delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	wync_advance_ticks(single_wync.ctx)
	

static func wync_advance_ticks(ctx: WyncCtx):
	
	ctx.co_ticks.ticks += 1
	ctx.co_ticks.server_ticks += 1
	ctx.co_ticks.lerp_delta_accumulator_ms = 0
