class_name WyncEventUtils

# Events utilities
# ================================================================
# TODO: write tests for this
static func _get_new_event_id(ctx: WyncCtx) -> int:
	# get my peer id (1 byte, 255 max)
	var peer_id = ctx.my_peer_id
	
	"""
	# alternative approach:
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
	assert(event_id > 0)
	return event_id


## @returns Optional<int>. event_id
static func instantiate_new_event(
	ctx: WyncCtx,
	event_type_id: int,
	) -> Variant:
	if not ctx.connected:
		return null
		
	var event_id = _get_new_event_id(ctx)
	var event = WyncEvent.new()
	event.data = WyncEvent.EventData.new()
	event.data.event_type_id = event_type_id
	event.data.event_data = null

	ctx.events[event_id] = event
	return event_id


## @returns int. 0 -> ok, (int > 0) -> error
static func event_set_data(
		ctx: WyncCtx,
		event_id: int,
		event_data: Variant,
		#event_size: int
	) -> int:
	
	var event = ctx.events[event_id]
	if event is not WyncEvent:
		return 1
	event = event as WyncEvent
	event.data.event_data = event_data
	return 0


## @returns Optional<int>. null -> error, int -> event id
static func event_wrap_up(
		ctx: WyncCtx,
		event_id: int,
	) -> Variant:
		
	var event = ctx.events[event_id]
	if event is not WyncEvent:
		return null
	event = event as WyncEvent
	
	var event_hash = HashUtils.hash_any(event.data)
	
	# this event is a duplicate
	if ctx.events_hash_to_id.has_item_hash(event_hash):
		ctx.events.erase(event_id)
		var cached_event_id = ctx.events_hash_to_id.get_item_by_hash(event_hash)
		print("WyncCtx: EventData: this event is a duplicate")
		return cached_event_id
	
	# not a duplicate -> cache it
	ctx.events_hash_to_id.push_head_hash_and_item(event_hash, event_id)
	return event_id


## Call this function whenever creating a global event
# TODO: Save client_id of origin or entity_id of origin somewhere

# static func prop_global_event_publish
"""
static func global_event_publish_on_demand \
	(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	if (not WyncUtils.prop_exists(ctx, prop_id)):
		return 1
	var prop = ctx.props[prop_id] as WyncEntityProp
	if (prop == null):
		return 2
	if (!prop.push_to_global_event):
		return 3
	if (prop.data_type != WyncEntityProp.DATA_TYPE.EVENT):
		return 4
	var channel = prop.global_event_channel
	if (channel < 0 || channel > ctx.max_channels):
		return 5

	# no need to check event_id here, we check it when consuming
	ctx.global_events_channel[channel].append(event_id)
	# event.prop_id = prop_id
	return 0"""


static func publish_global_event_as_client \
	(ctx: WyncCtx, channel: int, event_id: int) -> int:
	if (channel < 0 || channel > ctx.max_channels):
		return 5
	
	# TODO: improve safety
	ctx.peer_has_channel_has_events[ctx.my_peer_id][channel].append(event_id)
	return 0


static func publish_global_event_as_server \
	(ctx: WyncCtx, channel: int, event_id: int) -> int:
	if (channel < 0 || channel > ctx.max_channels):
		return 5
	
	ctx.peer_has_channel_has_events[WyncCtx.SERVER_PEER_ID][channel].append(event_id)
	return 0


static func global_event_consume \
	(ctx: WyncCtx, peer_id: int, channel_id: int, event_id: int) -> int:
	if channel_id < 0 || channel_id >= ctx.max_channels:
		return 1
	
	if not ctx.peer_has_channel_has_events[peer_id][channel_id].has(event_id):
		return 2
	
	ctx.peer_has_channel_has_events[peer_id][channel_id].erase(event_id)
	return 0
	
	# NOTE: What about the duplicated state
	# on the user's event container?
	#return 0 if ctx.events.erase(event_id) else 1


# ==================================================================
# Action functions, not related to Events


static func action_already_ran_on_tick(ctx: WyncCtx, predicted_tick: int, action_id: String) -> bool:
	var action_set = ctx.tick_action_history.get_at(predicted_tick)
	if action_set is not Dictionary:
		return false
	action_set = action_set as Dictionary
	return action_set.has(action_id)


static func action_mark_as_ran_on_tick(ctx: WyncCtx, predicted_tick: int, action_id: String) -> int:
	var action_set = ctx.tick_action_history.get_at(predicted_tick)
	# This error should never happen as long as we initialize it correctly
	# However, the user might provide any 'tick' which would result in
	# confusing results
	if action_set is not Dictionary:
		return 1
	action_set = action_set as Dictionary
	action_set[action_id] = true
	return 0


# run once each game tick
static func action_tick_history_reset(ctx: WyncCtx, predicted_tick: int) -> int:
	var action_set = ctx.tick_action_history.get_at(predicted_tick)
	if action_set is not Dictionary:
		return 1
	action_set = action_set as Dictionary
	action_set.clear()
	return 0


# FIXME: This func isn't being used, despite being important from optimization
# Currently events are being added by extraction

"""
static func add_event_to_prop_tick(
		ctx: WyncCtx,
		event_id: int,
		prop_id: int,
		tick_current: int,
	) -> int:
	
	# TODO: Where to define if this event can be duplicated?
	#var tick_pred = co_predict_data.target_tick
	# save tick relationship
	#co_predict_data.set_tick_predicted(tick_pred, tick_curr)
	# Compensate for UP smooth tick_offset transition
	# check if previous input is missing -> then duplicate
	#if not co_predict_data.get_tick_predicted(tick_pred-1):
		#co_predict_data.set_tick_predicted(tick_pred-1, tick_curr)
	
	# save input to actual prop
	
	if !(prop_id >= 0 && prop_id < ctx.props.size()):
		return 1
	var input_prop = ctx.props[prop_id] as WyncEntityProp
	if input_prop == null:
		return 2
	
	# reset in case it doesn't exist
	var data_wrap = input_prop.confirmed_states.get_at(tick_current)
	if data_wrap == null || data_wrap is not WyncPktInputs.NetTickDataDecorator:
		data_wrap = WyncPktInputs.NetTickDataDecorator.new()
		data_wrap.tick = tick_current
		data_wrap.data = []
		input_prop.confirmed_states.insert_at(tick_current, data_wrap)
	
	data_wrap = data_wrap as WyncPktInputs.NetTickDataDecorator
	if data_wrap.tick != tick_current:
		data_wrap.tick = tick_current
		(data_wrap.data as Array).clear() # NOTE: maybe just Array.clear()?
	
	(data_wrap.data as Array).append(event_id)
	return 0
"""
"""
instantiate_new_event(event_type_id) -> event_id

event_add_arg(arg_type: enum, arg_data: any)

entity_event_prop_add_new(event_type_id, tick)

func tick_set_event(
	co_predict_data: CoPredictionData,
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
