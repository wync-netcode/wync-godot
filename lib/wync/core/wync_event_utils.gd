class_name WyncEventUtils


# ==================================================
# Public API
# ==================================================


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
	event_user_type_id: int,
	) -> Variant:
	if not ctx.connected:
		return null
		
	var event_id = _get_new_event_id(ctx)
	var event = WyncCtx.WyncEvent.new()
	event.data = WyncCtx.WyncEventEventData.new()
	event.data.event_type_id = event_user_type_id
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
	if event is not WyncCtx.WyncEvent:
		return 1
	event = event as WyncCtx.WyncEvent
	event.data.event_data = event_data
	return 0


## @returns Optional<int>. null -> error, int -> event id
static func _event_wrap_up(
		ctx: WyncCtx,
		event_id: int,
	) -> Variant:
		
	var event := ctx.events[event_id]
	if event == null:
		return null
	
	event.data_hash = HashUtils.hash_any(event.data)
	
	# this event is a duplicate
	if ctx.events_hash_to_id.has_item_hash(event.data_hash):
		ctx.events.erase(event_id)
		var cached_event_id = ctx.events_hash_to_id.get_item_by_hash(event.data_hash)
		print("WyncCtx: EventData: this event is a duplicate")
		return cached_event_id
	
	# not a duplicate -> cache it
	ctx.events_hash_to_id.push_head_hash_and_item(event.data_hash, event_id)
	return event_id


## @returns Optional<int>. null -> error, int -> event id
static func new_event_wrap_up(
	ctx: WyncCtx,
	event_user_type_id: int,
	event_data: Variant,
	) -> Variant:

	var event_id = WyncEventUtils.instantiate_new_event(ctx, event_user_type_id)
	if event_id == null:
		return null
	WyncEventUtils.event_set_data(ctx, event_id, event_data)
	return WyncEventUtils._event_wrap_up(ctx, event_id)


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


# ==================================================================
## Sending events


static func wync_send_event_data (ctx: WyncCtx):
	if not ctx.connected:
		Log.errc(ctx, "Not connected")
		return

	# send events
	
	if ctx.is_client:
		wync_system_send_events_to_peer(ctx, WyncCtx.SERVER_PEER_ID)
	else: # server
		for wync_peer_id in range(1, ctx.peers.size()):
			wync_system_send_events_to_peer(ctx, wync_peer_id)


## This system writes state
## This system should run just after queue_delta_event_data_to_be_synced_to_peers
## All queued events must be sent, they're already commited, so no throttling here
## @returns int: 0 -> OK, 1 -> OK, but couldn't queue all packets, >1 -> Error
static func wync_system_send_events_to_peer (ctx: WyncCtx, wync_peer_id: int) -> int:
	
	var event_keys = ctx.peers_events_to_sync[wync_peer_id].keys()
	var event_amount = event_keys.size()
	if event_amount <= 0:
		return OK
	
	var data = WyncPktEventData.new()
	
	for i in range(event_amount):
		var event_id = event_keys[i]
		#Log.out(self, "event_id %s" % event_id)
		
		# get event data
		
		if not ctx.events.has(event_id):
			Log.errc(ctx, "couldn't find event_id %s" % event_id)
			continue
		
		var wync_event := ctx.events[event_id]
		var wync_event_data = wync_event.data
		
		# check if peer already has it
		# NOTE: is_serve_cached could be skipped? all events should be cached on our side...
		var is_event_cached = ctx.events_hash_to_id.has_item_hash(wync_event.data_hash)
		if (is_event_cached):
			var cached_event_id = ctx.events_hash_to_id.get_item_by_hash(wync_event.data_hash)
			if (cached_event_id != null):
				#see ctx.max_amount_cache_events
				var peer_has_it = ctx.to_peers_i_sent_events[wync_peer_id].has_item_hash(cached_event_id)
				if (peer_has_it):
					continue
		
		# package it
		
		var event_data = WyncPktEventData.EventData.new()
		event_data.event_id = event_id
		event_data.event_type_id = wync_event_data.event_type_id
		event_data.event_data = wync_event_data.event_data
		data.events.append(event_data)

		# confirm commit (these events are all aready commited)
		# since peer doesn't have it, then mark it as sent
		ctx.to_peers_i_sent_events[wync_peer_id].push_head_hash_and_item(event_id, true)
	

	if (data.events.size() == 0):
		return OK
	
	# queue

	var packet_dup = WyncMisc.duplicate_any(data)
	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_EVENT_DATA, packet_dup)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)

	Log.outc(ctx, "sent")

	return OK


# ==================================================================
# "Events Consumed" prop module / add-on


# server only?
static func prop_set_module_events_consumed(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.module_events_consumed = true
	prop.events_consumed_at_tick = RingBuffer.new(ctx.max_age_user_events_for_consumption, [] as Array[int])
	prop.events_consumed_at_tick_tick = RingBuffer.new(ctx.max_age_user_events_for_consumption, -1)
	return OK


static func global_event_consume_tick \
	(ctx: WyncCtx, wync_peer_id: int, channel: int, tick: int, event_id: int) -> void:
	
	assert(channel >= 0 && channel < ctx.max_channels)
	assert(wync_peer_id >= 0 && wync_peer_id < ctx.max_peers)
	
	var prop_id: int = ctx.prop_id_by_peer_by_channel[wync_peer_id][channel]
	var prop_channel := WyncTrack.get_prop_unsafe(ctx, prop_id)

	var consumed_event_ids_tick: int = prop_channel.events_consumed_at_tick_tick.get_at(tick)
	if tick != consumed_event_ids_tick:
		return

	var consumed_events: Array[int] = prop_channel.events_consumed_at_tick.get_at(tick)
	consumed_events.append(event_id)


static func module_events_consumed_advance_tick(ctx: WyncCtx):
	var tick = ctx.co_ticks.ticks

	for prop_id: int in ctx.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		if not prop.module_events_consumed:
			continue

		prop.events_consumed_at_tick_tick.insert_at(tick, tick)
		var event_ids: Array[int] = prop.events_consumed_at_tick.get_at(tick)
		event_ids.clear()


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


# TODO: as the server, only receive event data from a client if they own a prop with it
# There might not be a very performant way of doing that
static func wync_handle_pkt_event_data(ctx: WyncCtx, data: Variant) -> int:

	if data is not WyncPktEventData:
		return 1
	data = data as WyncPktEventData

	for event: WyncPktEventData.EventData in data.events:
		
		var wync_event = WyncCtx.WyncEvent.new()
		wync_event.data.event_type_id = event.event_type_id
		wync_event.data.event_data = event.event_data
		ctx.events[event.event_id] = wync_event
	
		#Log.out("events | got this events %s" % [event.event_id], Log.TAG_EVENT_DATA)
		if event.event_id == 105:
			print_debug("")
		# NOTE: what if we already have this event data? Maybe it's better to receive it anyway?

	return OK


## Q: Is it possible that event_ids accumulate infinitely if they are never consumed?
## A: No, if events are never consumed they remain in the confirmed_states buffer until eventually replaced.
## Returns events from this tick, that aren't consumed
static func wync_get_events_from_channel_from_peer(
	ctx: WyncCtx, wync_peer_id: int, channel: int, tick: int
	) -> Array[int]:

	var out_events_id: Array[int] = []
	if tick < 0:
		return out_events_id

	var prop_id: int = ctx.prop_id_by_peer_by_channel[wync_peer_id][channel]
	var prop_channel := WyncTrack.get_prop_unsafe(ctx, prop_id)

	var consumed_event_ids_tick: int = prop_channel.events_consumed_at_tick_tick.get_at(tick)
	if tick != consumed_event_ids_tick:
		return out_events_id

	var consumed_event_ids: Array[int] = prop_channel.events_consumed_at_tick.get_at(tick)
	var confirmed_event_ids: Array

	if ctx.co_ticks.ticks == tick:
		confirmed_event_ids = ctx.peer_has_channel_has_events[wync_peer_id][channel]
	else:
		# TODO: Rewrite me
		var state = WyncEntityProp.saved_state_get(prop_channel, tick)
		if state == null:
			return out_events_id
		confirmed_event_ids = state

	for i in range(confirmed_event_ids.size()):
		var event_id = confirmed_event_ids[i]
		if consumed_event_ids.has(event_id):
			continue
		if not ctx.events.has(event_id):
			continue

		var event := ctx.events[event_id]
		assert(event != null)
		out_events_id.append(event_id)

	return out_events_id


# ==================================================
# WRAPPER
# ==================================================


# run on both server & client to set up peer channel
# NOTE: Maybe it's better to initialize all client channels from the start
static func setup_peer_global_events(ctx: WyncCtx, peer_id: int) -> int:
	assert(ctx.connected)
	
	var entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + peer_id
	WyncTrack.track_entity(ctx, entity_id, -1)
	var channel_id = 0
	var channel_prop_id = WyncTrack.prop_register_minimal(
		ctx,
		entity_id,
		"channel_%d" % [channel_id],
		WyncEntityProp.PROP_TYPE.EVENT
	)
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		channel_prop_id,
		ctx,
		func(wync_ctx: Variant) -> Array: # getter
			return (wync_ctx as WyncCtx).peer_has_channel_has_events[peer_id][channel_id].duplicate(true),
		func(wync_ctx: Variant, input: Array): # setter
			var event_array = (wync_ctx as WyncCtx).peer_has_channel_has_events[peer_id][channel_id] as Array
			event_array.clear()
			event_array.append_array(input),
	)

	# TODO: add as VIP prop

	# predict my own global channel
	if (ctx.is_client && peer_id == ctx.my_peer_id):
		WyncXtrap.prop_set_predict(ctx, channel_prop_id)

	# TODO: why only run on server? Q: ...
	#if not ctx.is_client:
	if true:
		# add as local existing prop
		WyncTrack.wync_add_local_existing_entity(ctx, peer_id, entity_id)
		# server module for consuming user events
		WyncEventUtils.prop_set_module_events_consumed(ctx, channel_prop_id)
		# populate ctx var
		ctx.prop_id_by_peer_by_channel[peer_id][channel_id] = channel_prop_id

	return 0
