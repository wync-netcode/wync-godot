class_name WyncEventUtils

# Events utilities
# ================================================================
# TODO: write tests for this
static func _get_new_event_id(ctx: WyncCtx) -> int:
	# get my peer id (1 byte, 255 max)
	var peer_id = ctx.my_client_id
	
	"""
	# alternative option:
	# 32 24 16 08
	# X  X  X  Y
	# X = event_id, Y = peer_id
	var event_id = ctx.event_id_counter << 8
	event_id += peer_id & (2**8-1)
	"""
	
	# generate an event id ending in my peer id
	ctx.event_id_counter += 1
	var event_id = peer_id << 24
	event_id += ctx.event_id_counter & (2**24-1)
	
	# reset event_id_counter every 2^24 (3 bytes)
	if ctx.event_id_counter >= (2**24-1):
		ctx.event_id_counter = 0
		
	# return the generated id
	return event_id


## @returns int event_id
static func instantiate_new_event(
	ctx: WyncCtx,
	event_type_id: int,
	arg_count: int
	) -> int:
		
	var id = _get_new_event_id(ctx)
	var event = WyncEvent.new()
	event.event_id = id
	event.event_type_id = event_type_id
	event.arg_count = arg_count
	event.arg_data.resize(arg_count)
	event.arg_data_type.resize(arg_count)
	ctx.events[id] = event
	return id


static func event_add_arg(
		ctx: WyncCtx,
		event_id: int,
		arg_id: int,
		arg_data_type: int,
		arg_data # : any
	) -> int:
	
	var event = ctx.events[event_id]
	if event is not WyncEvent:
		return 1
	event = event as WyncEvent
	if event.arg_count >= arg_id:
		return 2
	event.arg_data_type[arg_id] = arg_data_type
	event.arg_data[arg_id] = arg_data
	return 0


# FIXME: This func isn't being used, despite being important from optimization
# Currently events are being added by extraction

static func add_event_to_prop_tick(
		ctx: WyncCtx,
		event_id: int,
		prop_id: int,
		tick_current: int,
	) -> int:
	
	# TODO: Where to define if this event can be duplicated?
	"""
	var tick_pred = co_predict_data.target_tick
	# save tick relationship
	co_predict_data.set_tick_predicted(tick_pred, tick_curr)
	# Compensate for UP smooth tick_offset transition
	# check if previous input is missing -> then duplicate
	if not co_predict_data.get_tick_predicted(tick_pred-1):
		co_predict_data.set_tick_predicted(tick_pred-1, tick_curr)
	"""
	
	# save input to actual prop
	
	if !(prop_id >= 0 && prop_id < ctx.props.size()):
		return 1
	var input_prop = ctx.props[prop_id] as WyncEntityProp
	if input_prop == null:
		return 2
	
	# reset in case it doesn't exist
	var data_wrap = input_prop.confirmed_states.get_at(tick_current)
	if data_wrap == null || data_wrap is not NetPacketInputs.NetTickDataDecorator:
		data_wrap = NetPacketInputs.NetTickDataDecorator.new()
		data_wrap.tick = tick_current
		data_wrap.data = []
		input_prop.confirmed_states.insert_at(tick_current, data_wrap)
	
	data_wrap = data_wrap as NetPacketInputs.NetTickDataDecorator
	if data_wrap.tick != tick_current:
		data_wrap.tick = tick_current
		(data_wrap.data as Array).clear() # NOTE: maybe just Array.clear()?
	
	(data_wrap.data as Array).append(event_id)
	return 0

"""
instantiate_new_event(event_type_id) -> event_id

event_add_arg(arg_type: enum, arg_data: any)

entity_event_prop_add_new(event_type_id, tick)

func tick_set_event(
	co_predict_data: CoSingleNetPredictionData,
	wync_ctx: WyncCtx,
	input_prop_id: int,
	tick_curr: int,
	event_id: uint
	) -> void:
		
	var tick_pred = co_predict_data.target_tick
	
	# save tick relationship
	
	co_predict_data.set_tick_predicted(tick_pred, tick_curr)
	# Compensate for UP smooth tick_offset transition
	# check if previous input is missing -> then duplicate
	if not co_predict_data.get_tick_predicted(tick_pred-1):
		co_predict_data.set_tick_predicted(tick_pred-1, tick_curr)
	
	# save input to actual prop
	
	var input_prop = wync_ctx.props[input_prop_id] as WyncEntityProp
	if input_prop == null:
		return
	
	input_prop.confirmed_states.insert_at(tick_curr, input)
"""
