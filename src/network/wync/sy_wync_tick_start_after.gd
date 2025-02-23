extends System
class_name SyWyncTickStartAfter
const label: StringName = StringName("SyWyncTickStartAfter")

## Wync needs to run some things at the start of a game tick

var sy_wync_receive_event_data = SyWyncReceiveEventData.new()
var sy_wync_receive_apply_inputs = SyWyncReceiveApplyInputs.new()

func on_process(_entities, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# client tick start
	if WyncUtils.is_client(wync_ctx):
		sy_wync_receive_event_data.on_process([], null, _delta, self)
	
	# server tick start
	else:
		sy_wync_receive_event_data.on_process([], null, _delta, self)

		# feed props DATA_TYPE.EVENT
		sy_wync_receive_apply_inputs.on_process([], null, _delta, self)

		# extract events from global event props
		# TODO: global events can be generated during _process loop only in clients machine...
		# DEPRECATED
		# WyncUtils.system_publish_global_events(wync_ctx, co_ticks.ticks)

	auxiliar_props_clear_current_delta_events(wync_ctx)
	predicted_props_clear_events(wync_ctx)
	

static func auxiliar_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id: int in range(ctx.props.size()):
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.relative_syncable:
			continue
		prop.current_delta_events.clear()
		
		var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			continue
		aux_prop = aux_prop as WyncEntityProp
		aux_prop.current_undo_delta_events.clear()


static func predicted_props_clear_events(ctx: WyncCtx):
	for prop_id: int in range(ctx.props.size()):
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if prop.data_type != WyncEntityProp.DATA_TYPE.EVENT:
			continue
		if not WyncUtils.prop_is_predicted(ctx, prop_id):
			continue
		prop.setter.call([] as Array[int])
