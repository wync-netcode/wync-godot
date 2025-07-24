class_name WyncStateStore ## WyncStateKeep WyncStateSave


static func wync_client_update_last_tick_received(ctx: WyncCtx, tick: int):
	ctx.last_tick_received = max(ctx.last_tick_received, tick)
	ctx.last_tick_received_at_tick = ctx.co_ticks.ticks


static func wync_handle_pkt_prop_snap(ctx: WyncCtx, data: Variant):

	if data is not WyncPktSnap:
		return 1
	data = data as WyncPktSnap

	for snap_prop: WyncPktSnap.SnapProp in data.snaps:

		WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_PROP_SNAP, snap_prop.prop_id)

		var prop = WyncTrack.get_prop(ctx, snap_prop.prop_id)
		if prop == null:
			Log.warc(ctx, "couldn't find prop (%s) saving as dummy prop..." % [snap_prop.prop_id])
			WyncTrack.prop_register_update_dummy(ctx, snap_prop.prop_id, data.tick, 99, snap_prop.state)
			continue

		# avoid flooding the buffer with old late state
		var last_tick_received = prop.last_ticks_received.get_relative(0)
		if not (data.tick > last_tick_received - ctx.REGULAR_PROP_CACHED_STATE_AMOUNT):
			continue
		prop_save_confirmed_state(ctx, snap_prop.prop_id, data.tick, snap_prop.state)

		# update entity last received
		# TODO: assume snap props always include all snaps for an entity ???
		if WyncXtrap.prop_is_predicted(ctx, snap_prop.prop_id):
			var entity_id = WyncTrack.prop_get_entity(ctx, snap_prop.prop_id)
			ctx.entity_last_received_tick[entity_id] = WyncXtrapInternal.wync_xtrap_entity_get_last_received_tick_from_pred_props(ctx, entity_id)

	wync_client_update_last_tick_received(ctx, data.tick)


static func prop_save_confirmed_state(ctx: WyncCtx, prop_id: int, tick: int, state: Variant) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncProp

	prop.just_received_new_state = true
	prop.last_ticks_received.push(tick)
	prop.last_ticks_received.sort()
	prop.state_id_to_local_tick.insert_at(prop.saved_states.head_pointer, ctx.co_ticks.ticks)

	WyncProp.saved_state_insert(ctx, prop, tick, state)

	if prop.relative_syncable:
		# FIXME: check for max? what about unordered packets?
		var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
		delta_props_last_tick[prop_id] = tick 

	# update prob prop update rate
	if prop_id == ctx.PROP_ID_PROB:
		WyncStats.wync_try_to_update_prob_prop_rate(ctx)

	return OK


static func wync_service_cleanup_dummy_props(ctx: WyncCtx):
	# run every few frames
	#if ctx.co_ticks.ticks % 10 != 0:
	if WyncMisc.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
		return

	var curr_tick = ctx.co_ticks.server_ticks
	var dummy: WyncCtx.DummyProp = null

	for prop_id: int in ctx.dummy_props.keys():

		dummy = ctx.dummy_props[prop_id]
		if (curr_tick - dummy.last_tick) < WyncCtx.MAX_DUMMY_PROP_TICKS_ALIVE:
			continue

		# delete dummy prop

		ctx.dummy_props.erase(prop_id)
		ctx.stat_lost_dummy_props += 1


static func wync_server_handle_pkt_inputs(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:
	if not ctx.connected:
		return 1
	if data is not WyncPktInputs:
		return 2
	data = data as WyncPktInputs

	WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_INPUTS, data.prop_id)

	# client and prop exists
	var client_id = WyncJoin.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.errc(ctx, "client %s is not registered" % from_nete_peer_id)
		return 3
	var prop_id = data.prop_id
	if not WyncTrack.prop_exists(ctx, prop_id):
		Log.errc(ctx, "prop %s doesn't exists" % prop_id)
		return 4
	
	# check client has ownership over this prop
	var client_owns_prop = false
	for i_prop_id in ctx.client_owns_prop[client_id]:
		if i_prop_id == prop_id:
			client_owns_prop = true
	if not client_owns_prop:
		return 5
	
	var input_prop := WyncTrack.get_prop(ctx, prop_id)
	if input_prop == null:
		return 6
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	for input: WyncPktInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncMisc.duplicate_any(input.data)
		if copy == null:
			Log.outc(ctx, "WARNING: input data can't be duplicated %s" % [input.data])
		var to_insert = copy

		# TODO: reject input that is too old
		
		WyncProp.saved_state_insert_in_place(ctx, input_prop, input.tick, to_insert)
		#Log.outc(ctx, "couldn't find input | inserted input (%s) tick (%s) value (%s)" % [input_prop.name_id, input.tick, copy])

	return OK


static func wync_client_handle_pkt_inputs(ctx: WyncCtx, data: Variant) -> int:
	if not ctx.connected:
		return 1
	if data is not WyncPktInputs:
		return 2
	data = data as WyncPktInputs

	WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_INPUTS, data.prop_id)

	var prop := WyncTrack.get_prop(ctx, data.prop_id)
	if prop == null:
		Log.warc(ctx, "prop %s doesn't exists, dropping input..." % data.prop_id)
		return 4
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	var max_tick = -1
	
	for input: WyncPktInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncMisc.duplicate_any(input.data)
		if copy == null:
			Log.warc(ctx, "input data can't be duplicated %s" % [input.data])
		var to_insert = copy if copy != null else input.data

		prop.last_ticks_received.push(input.tick)
		
		WyncProp.saved_state_insert(ctx, prop, input.tick, to_insert)
		max_tick = max(max_tick, input.tick)

	prop.last_ticks_received.sort()

	wync_client_update_last_tick_received(ctx, max_tick)

	# update entity last received
	if WyncXtrap.prop_is_predicted(ctx, data.prop_id):
		var entity_id = WyncTrack.prop_get_entity(ctx, data.prop_id)
		ctx.entity_last_received_tick[entity_id] = WyncXtrapInternal.wync_xtrap_entity_get_last_received_tick_from_pred_props(ctx, entity_id)

	return OK


static func wync_insert_state_to_entity_prop (
	ctx: WyncCtx, entity_id: int, prop_name_id: String, tick: int, state: Variant) -> int:

	var prop = WyncTrack.entity_get_prop(ctx, entity_id, prop_name_id)
	if prop == null:
		return 1
	prop = prop as WyncProp

	# Note: The code below was copied from 'prop_save_confirmed_state'

	prop.last_ticks_received.push(tick)
	prop.last_ticks_received.sort()

	WyncProp.saved_state_insert(ctx, prop, tick, state)

	prop.state_id_to_local_tick.insert_at(prop.saved_states.head_pointer, ctx.co_ticks.ticks)

	prop.just_received_new_state = true

	return OK
