extends System
class_name SyWyncTickStartBefore
const label: StringName = StringName("SyWyncTickStartBefore")

## Wync needs to run some things at the start of a game tick

var sy_wync_buffered_inputs = SyWyncBufferedInputs.new()

func on_process(_entities, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# client tick start
	if WyncUtils.is_client(wync_ctx):
		sy_wync_buffered_inputs.on_process([], null, _delta, self)
	
	# server tick start
	else:
		pass
	
