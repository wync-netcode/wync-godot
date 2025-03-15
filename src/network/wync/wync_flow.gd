class_name WyncFlow


## Note. Before running this, make sure to receive packets from the network

static func wync_server_tick_start(ctx: WyncCtx):
	# before tick start

	SyTicks.wync_advance_ticks(ctx)

	# after tick start

	WyncWrapper.wync_input_props_set_tick_value(ctx)

	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)


static func wync_server_tick_end(ctx: WyncCtx):
	SyWyncStateExtractor.update_delta_base_state_tick(ctx)

	# NOTE: maybe a way to extract data but only events, since that is unskippable?
	# This function extracts regular props, plus _auxiliar delta event props_
	# We need a function to extract data exclusively of events... Like the equivalent
	# of the client's _input_bufferer_
	WyncWrapper.extract_data_to_tick(ctx, ctx.co_ticks.ticks)


static func wync_client_tick_end(ctx: WyncCtx):

	SyTicks.wync_advance_ticks(ctx)
	WyncThrottle.wync_system_stabilize_latency(ctx)
	SyNetPredictionTicks.wync_update_prediction_ticks(ctx)
	
	WyncWrapper.wync_buffer_inputs(ctx)

	# CANNOT reset events BEFORE polling inputs, WHERE do we put this?
	
	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)
	WyncDeltaSyncUtils.predicted_props_clear_events(ctx)

	SyWyncLatestValue.wync_reset_props_to_latest_value(ctx)
	
	# NOTE: Maybe this one should be called AFTER consuming packets, and BEFORE xtrap
	wync_system_calculate_prob_prop_rate(ctx)

	wync_system_calculate_server_tick_rate(ctx)

	WyncFlow.wync_dummy_props_cleanup(ctx)

	SyWyncLerpPrecompute.wync_lerp_precompute(ctx)


static func wync_feed_packet(ctx: WyncCtx, wync_pkt: WyncPacket, from_nete_peer_id: int) -> int:

	# debug statistics
	WyncDebug.log_packet_received(ctx, wync_pkt.packet_type_id)
	var is_client = ctx.is_client

	# tick rate calculation	
	if is_client:
		wync_report_update_received(ctx)
		#Log.outc(ctx, "tagtps | tag1 | tick(%s) received packet %s" % [ctx.co_ticks.ticks, WyncPacket.PKT_NAMES[wync_pkt.packet_type_id]])
	#else:
		#Log.outc(ctx, "setted | tick(%s) received packet %s" % [ctx.co_ticks.ticks, WyncPacket.PKT_NAMES[wync_pkt.packet_type_id]])

	match wync_pkt.packet_type_id:
		WyncPacket.WYNC_PKT_JOIN_REQ:
			if not is_client:
				wync_handle_pkt_join_req(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_JOIN_RES:
			if is_client:
				wync_handle_pkt_join_res(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_EVENT_DATA:
			wync_handle_pkt_event_data(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_INPUTS:
			if is_client:
				wync_client_handle_pkt_inputs(ctx, wync_pkt.data)
			else:
				wync_server_handle_pkt_inputs(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_PROP_SNAP:
			if is_client:
				# TODO: in the future we might support client authority
				wync_handle_pkt_prop_snap(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_RES_CLIENT_INFO:
			if is_client:
				wync_handle_packet_res_client_info(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_CLOCK:
			if is_client:
				wync_handle_pkt_clock(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_CLIENT_SET_LERP_MS:
			if not is_client:
				wync_handle_packet_client_set_lerp_ms(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_SPAWN:
			if is_client:
				wync_handle_pkt_spawn(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_DESPAWN:
			if is_client:
				wync_handle_pkt_despawn(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_DELTA_PROP_ACK:
			if not is_client:
				wync_handle_pkt_delta_prop_ack(ctx, wync_pkt.data, from_nete_peer_id)
		_:
			Log.err("wync packet_type_id(%s) not recognized skipping (%s)" % [wync_pkt.packet_type_id, wync_pkt.data])
			return -1

	return OK


static func wync_client_update_last_tick_received(ctx: WyncCtx, tick: int):
	ctx.last_tick_received = max(ctx.last_tick_received, tick)


static func wync_packet_type_exists(packet_type_id: int) -> bool:
	return packet_type_id >= 0 && packet_type_id < WyncPacket.WYNC_PKT_AMOUNT


## Wraps a valid packet in a WyncPacket in a WyncPacketOut for delivery
## @param packet: void*. A pointer to the packet data
## @returns Tuple[int, WyncPacketOut]. [0] -> Error; [1] -> WyncPacketOut.
static func wync_wrap_packet_out(ctx: WyncCtx, to_wync_peer_id: int, packet_type_id: int, data: Variant) -> Array:

	if not wync_packet_type_exists(packet_type_id):
		Log.err("Invalid packet_type_id(%s)" % [packet_type_id])
		return [1, null]

	var nete_peer_id = WyncUtils.get_nete_peer_id_from_wync_peer_id(ctx, to_wync_peer_id)
	if nete_peer_id == -1:
		Log.err("Couldn't find a nete_peer_id for wync_peer_id(%s)" % [to_wync_peer_id])
		return [2, null]

	var wync_pkt = WyncPacket.new()
	wync_pkt.packet_type_id = packet_type_id
	wync_pkt.data = data

	var wync_pkt_out = WyncPacketOut.new()
	wync_pkt_out.to_nete_peer_id = nete_peer_id
	wync_pkt_out.data = wync_pkt

	return [OK, wync_pkt_out]


static func wync_wrap_packet_out_from_wync_pkt(ctx: WyncCtx, to_wync_peer_id: int, packet_type_id: int, data: WyncPacket) -> Array:

	if not wync_packet_type_exists(packet_type_id):
		Log.err("Invalid packet_type_id(%s)" % [packet_type_id])
		return [1, null]

	var nete_peer_id = WyncUtils.get_nete_peer_id_from_wync_peer_id(ctx, to_wync_peer_id)
	if nete_peer_id == -1:
		Log.err("Couldn't find a nete_peer_id for wync_peer_id(%s)" % [to_wync_peer_id])
		return [2, null]

	var wync_pkt_out = WyncPacketOut.new()
	wync_pkt_out.to_nete_peer_id = nete_peer_id
	wync_pkt_out.data = data

	return [OK, wync_pkt_out]


static func wync_try_to_connect(ctx: WyncCtx) -> int:
	if ctx.connected:
		return OK

	# throttle
	#if ctx.co_ticks.ticks % 5 != 0:
	if WyncUtils.fast_modulus(ctx.co_ticks.ticks, 8) != 0:
		return OK

	# try get server nete_peer_id
	var server_nete_peer_id = WyncUtils.get_nete_peer_id_from_wync_peer_id(ctx, WyncCtx.SERVER_PEER_ID)
	if server_nete_peer_id == -1:
		return 1

	# send connect req packet
	# TODO: Move this elsewhere
	
	var packet_data := WyncPktJoinReq.new()
	var result = wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_JOIN_REQ, packet_data)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)

	# TODO: Ser lerpms could be moved somewhere else, since it could be sent anytime

	var packet_data_lerp := WyncPktClientSetLerpMS.new()
	packet_data_lerp.lerp_ms = ctx.co_predict_data.lerp_ms
	result = wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_CLIENT_SET_LERP_MS, packet_data_lerp)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)
	return OK


# packet consuming -----------------------------------------------------------


static func wync_handle_pkt_join_res(ctx: WyncCtx, data: Variant) -> int:

	if data is not WyncPktJoinRes:
		return 1
	data = data as WyncPktJoinRes
	
	if not data.approved:
		Log.err("Connection DENIED for client(%s) (me)" % [ctx.my_nete_peer_id], Log.TAG_WYNC_CONNECT)
		return 2
		
	# setup client stuff
	# NOTE: Move this elsewhere?
		
	ctx.connected = true
	ctx.my_peer_id = data.wync_client_id
	WyncUtils.client_setup_my_client(ctx, data.wync_client_id)

	Log.out("client nete_peer_id(%s) connected as wync_peer_id(%s)" % [ctx.my_nete_peer_id, ctx.my_peer_id], Log.TAG_WYNC_CONNECT, Log.TAG_DEBUG2)
	return OK


# TODO: as the server, only receive event data from a client if they own a prop with it
# There might not be a very performant way of doing that
static func wync_handle_pkt_event_data(ctx: WyncCtx, data: Variant) -> int:

	if data is not WyncPktEventData:
		return 1
	data = data as WyncPktEventData

	for event: WyncPktEventData.EventData in data.events:
		
		var wync_event = WyncEvent.new()
		wync_event.data.event_type_id = event.event_type_id
		wync_event.data.event_data = event.event_data
		ctx.events[event.event_id] = wync_event
	
		#Log.out("events | got this events %s" % [event.event_id], Log.TAG_EVENT_DATA)
		if event.event_id == 105:
			print_debug("")
		# NOTE: what if we already have this event data? Maybe it's better to receive it anyway?

	return OK


## This systems writes state
static func wync_handle_pkt_join_req(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktJoinReq:
		return 1
	data = data as WyncPktJoinReq
	
	# TODO: check it hasn't been setup yet
	# NOTE: the criteria to determine wether a client has a valid prop ownership could be user defined
	# NOTE: wync setup must be ran only once per client
	
	var wync_client_id = WyncUtils.is_peer_registered(ctx, from_nete_peer_id)
	if wync_client_id != -1:
		Log.out("Client %s already setup in Wync as %s" % [from_nete_peer_id, wync_client_id], Log.TAG_WYNC_CONNECT)
		return 1
	wync_client_id = WyncUtils.peer_register(ctx, from_nete_peer_id)
	
	# send confirmation
	
	var packet = WyncPktJoinRes.new()
	packet.approved = true
	packet.wync_client_id = wync_client_id
	var result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_JOIN_RES, packet)
	if result[0] == OK:
		WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], WyncCtx.RELIABLE, true)

	# let client own it's own global events
	# NOTE: Maybe move this where all channels are defined

	var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	var prop_id = WyncUtils.entity_get_prop_id(ctx, global_events_entity_id, "channel_0")
	assert(prop_id != -1)
	WyncUtils.prop_set_client_owner(ctx, prop_id, wync_client_id)

	#var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	#if WyncUtils.is_entity_tracked(ctx, global_events_entity_id):

		#var packet_info = make_client_info_packet(ctx, wync_client_id, global_events_entity_id, "channel_0")
		#result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet_info)
		#if result[0] == OK:
			#WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], WyncCtx.RELIABLE, true)
	
	#else:
		#Log.err("Global Event Entity (id %s) for peer_id %s NOT FOUND" % [global_events_entity_id, wync_client_id], Log.TAG_WYNC_CONNECT)

	# queue as pending for setup

	ctx.out_peer_pending_to_setup.append(from_nete_peer_id)

	return OK
	

#static func make_client_info_packet(
	#ctx: WyncCtx,
	#wync_client_id: int,
	#entity_id: int,
	#prop_name: String) -> WyncPktResClientInfo:
	
	#var prop_id = WyncUtils.entity_get_prop_id(ctx, entity_id, prop_name)
	#var packet_data = WyncPktResClientInfo.new()
	##packet_data.entity_id = entity_id
	#packet_data.prop_id = prop_id
	#packet_data.peer_id = wync_client_id
	
	#WyncUtils.prop_set_client_owner(ctx, prop_id, wync_client_id)
	#Log.out("assigned (entity %s: prop %s) to client %s" % [packet_data.entity_id, prop_id, wync_client_id], Log.TAG_WYNC_CONNECT)
	
	#return packet_data


static func wync_server_handle_pkt_inputs(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:
	if not ctx.connected:
		return 1
	if data is not WyncPktInputs:
		return 2
	data = data as WyncPktInputs

	WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_INPUTS, data.prop_id)

	# client and prop exists
	var client_id = WyncUtils.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.err("client %s is not registered" % client_id, Log.TAG_INPUT_RECEIVE)
		return 3
	var prop_id = data.prop_id
	if not WyncUtils.prop_exists(ctx, prop_id):
		Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_RECEIVE)
		return 4
	
	# check client has ownership over this prop
	var client_owns_prop = false
	for i_prop_id in ctx.client_owns_prop[client_id]:
		if i_prop_id == prop_id:
			client_owns_prop = true
	if not client_owns_prop:
		return 5
	
	var input_prop := WyncUtils.get_prop(ctx, prop_id)
	if input_prop == null:
		return 6
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	for input: WyncPktInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncUtils.duplicate_any(input.data)
		if copy == null:
			Log.out("WARNING: input data can't be duplicated %s" % [input.data], Log.TAG_INPUT_RECEIVE)
		var to_insert = copy
		
		input_prop.confirmed_states.insert_at(input.tick, to_insert)
		input_prop.confirmed_states_tick.insert_at(input.tick, input.tick)
		#Log.outc(ctx, "couldn't find input | inserted input (%s) tick (%s) value (%s)" % [input_prop.name_id, input.tick, copy])

	return OK


static func wync_client_handle_pkt_inputs(ctx: WyncCtx, data: Variant) -> int:
	if not ctx.connected:
		return 1
	if data is not WyncPktInputs:
		return 2
	data = data as WyncPktInputs

	WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_INPUTS, data.prop_id)

	var prop := WyncUtils.get_prop(ctx, data.prop_id)
	if prop == null:
		Log.err("prop %s doesn't exists" % data.prop_id, Log.TAG_INPUT_RECEIVE)
		return 4
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	var max_tick = -1
	
	for input: WyncPktInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncUtils.duplicate_any(input.data)
		if copy == null:
			Log.out("WARNING: input data can't be duplicated %s" % [input.data], Log.TAG_INPUT_RECEIVE)
		var to_insert = copy if copy != null else input.data
		
		prop.confirmed_states.insert_at(input.tick, to_insert)
		prop.confirmed_states_tick.insert_at(input.tick, input.tick)
		max_tick = max(max_tick, input.tick)

	if prop.is_auxiliar_prop:
		# TODO: See if this is necessary
		#var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
		#delta_props_last_tick[data.prop_id] = max_tick

		# notify _main delta prop_ about the updates
		var delta_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id) as WyncEntityProp
		delta_prop.just_received_new_state = true

	wync_client_update_last_tick_received(ctx, max_tick)

	return OK


# apply inputs / events to props
# TODO: Better to separate receive/apply logic
# NOTE: could this be merged with SyWyncLatestValue?
"""
static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			if not WyncUtils.prop_exists(ctx, prop_id):
				continue
			var prop := WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			if (prop.data_type != WyncEntityProp.DATA_TYPE.INPUT &&
				prop.data_type != WyncEntityProp.DATA_TYPE.EVENT):
				continue
		
			if prop.confirmed_states_tick.get_at(ctx.co_ticks.ticks) != ctx.co_ticks.ticks:
				Log.errc(ctx, "couldn't find input (%s) for tick (%s)" % [prop.name_id, ctx.co_ticks.ticks])
				continue

			var input = prop.confirmed_states.get_at(ctx.co_ticks.ticks)
			if input == null:
				continue

			prop.setter.call(prop.user_ctx_pointer, input)
			#Log.outc(ctx, "(tick %s) setted input prop (%s) to %s" % [ctx.co_ticks.ticks, prop.name_id, input])

	return OK
"""


static func wync_handle_pkt_prop_snap(ctx: WyncCtx, data: Variant):

	if data is not WyncPktSnap:
		return 1
	data = data as WyncPktSnap

	for snap_prop: WyncPktSnap.SnapProp in data.snaps:

		WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_PROP_SNAP, snap_prop.prop_id)

		var prop = WyncUtils.get_prop(ctx, snap_prop.prop_id)
		if prop == null:
			Log.errc(ctx, "couldn't find prop (%s) saving as dummy prop..." % [snap_prop.prop_id], Log.TAG_LATEST_VALUE)
			WyncUtils.prop_register_update_dummy(ctx, snap_prop.prop_id, data.tick, 99, snap_prop.state)
			continue

		# avoid flooding the buffer with old late state
		var last_tick_received = prop.last_ticks_received.get_relative(0)
		if not (data.tick > last_tick_received - ctx.REGULAR_PROP_CACHED_STATE_AMOUNT):
			continue
		prop_save_confirmed_state(ctx, snap_prop.prop_id, data.tick, snap_prop.state)

	wync_client_update_last_tick_received(ctx, data.tick)


static func prop_save_confirmed_state(ctx: WyncCtx, prop_id: int, tick: int, state: Variant) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
	
		# NOTE: two tick datas could have arrive at the same tick
		prop.last_ticks_received.push(tick)
		prop.last_ticks_received.sort()
		prop.confirmed_states.insert_at(tick, state)
		prop.confirmed_states_tick.insert_at(tick, tick)
		prop.arrived_at_tick.insert_at(tick, ctx.co_ticks.ticks)
		prop.just_received_new_state = true

		if prop.is_auxiliar_prop:
			# notify _main delta prop_ about the updates
			var delta_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id) as WyncEntityProp
			delta_prop.just_received_new_state = true

		# update prob prop update rate
		if prop_id == ctx.PROP_ID_PROB:
			wync_try_to_update_prob_prop_rate(ctx)


	else:

		# if a delta prop receives a fullsnapshot we have no other option but to comply
		# TODO: This might not be true on high _jitter_

		prop.setter.call(prop.user_ctx_pointer, state)
		prop.just_received_new_state = true
		var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
		delta_props_last_tick[prop_id] = tick
		#Log.out("debug_pred_delta_event | ser_tick(%s) delta_prop_last_tick %s" % [ctx.co_ticks.server_ticks, delta_props_last_tick], Log.TAG_LATEST_VALUE)

		# clean up predicted data TODO

		if WyncUtils.prop_is_predicted(ctx, prop_id):

			# get aux_prop and clean the confirmed_states_undo
			var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
			for j in range(ctx.first_tick_predicted, ctx.last_tick_predicted +1):
				aux_prop.confirmed_states.insert_at(j, [] as Array[int])
				aux_prop.confirmed_states_tick.insert_at(j, j)
				aux_prop.confirmed_states_undo.insert_at(j, [] as Array[int])
				aux_prop.confirmed_states_undo_tick.insert_at(j, j)

			# debugging: save canonic state to compare it later
			var state_dup = WyncUtils.duplicate_any(prop.getter.call(prop.user_ctx_pointer))
			prop.confirmed_states.insert_at(0, state_dup)
			prop.confirmed_states_tick.insert_at(0, 0)

	return OK


static func wync_handle_pkt_spawn(ctx: WyncCtx, data: Variant):

	if data is not WyncPktSpawn:
		return 1
	data = data as WyncPktSpawn

	var entity_to_spawn: WyncCtx.PendingEntityToSpawn = null
	for i: int in range(data.entity_amount):

		var entity_id = data.entity_ids[i]
		var entity_type_id = data.entity_type_ids[i]
		var prop_start = data.entity_prop_id_start[i]
		var prop_end = data.entity_prop_id_end[i]
		var spawn_data = data.entity_spawn_data[i]

		# "flag" it
		ctx.pending_entity_to_spawn_props[entity_id] = [prop_start, prop_end, 0] as Array[int]

		# queue it to user facing variable
		entity_to_spawn = WyncCtx.PendingEntityToSpawn.new()
		entity_to_spawn.already_spawned = false
		entity_to_spawn.entity_id = entity_id
		entity_to_spawn.entity_type_id = entity_type_id
		entity_to_spawn.spawn_data = spawn_data

		ctx.out_pending_entities_to_spawn.append(entity_to_spawn)


static func wync_handle_pkt_despawn(ctx: WyncCtx, data: Variant):

	if data is not WyncPktDespawn:
		return 1
	data = data as WyncPktDespawn

	for i: int in range(data.entity_amount):

		var entity_id = data.entity_ids[i]
		ctx.out_pending_entities_to_despawn.append(entity_id)

		WyncUtils.untrack_entity(ctx, entity_id)


static func wync_handle_pkt_delta_prop_ack(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktDeltaPropAck:
		return 1
	data = data as WyncPktDeltaPropAck

	# TODO: check client is healthy

	var client_id = WyncUtils.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.errc(ctx, "client %s is not registered" % client_id)
		return 2

	var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary

	# update latest _delta prop_ acked tick

	for i: int in range(data.prop_amount):
		var prop_id: int = data.delta_prop_ids[i]
		var last_tick: int = data.last_tick_received[i]

		if last_tick > ctx.co_ticks.ticks:
			continue

		var prop := WyncUtils.get_prop(ctx, prop_id)
		if not prop:
			Log.outc(ctx, "W: Couldn't find this prop %s" % [prop_id])
			continue

		if not client_relative_props.has(prop_id):
			Log.outc(ctx, "W: Client might no be 'seeing' this prop %s" % [prop_id])
			continue

		client_relative_props[prop_id] = last_tick

	return OK


static func wync_clear_entities_pending_to_despawn(ctx: WyncCtx):
	ctx.out_pending_entities_to_despawn.clear()


static func _wync_add_new_dummy_prop(ctx: WyncCtx, prop_id: int, data: Variant):
	pass
	#var pos_prop_id = WyncUtils.prop_register(
		#ctx,
		#co_actor.id,
		#"position",
		#WyncEntityProp.DATA_TYPE.VECTOR2,
		#func() -> Vector2: return co_collider.global_position,
		#func(pos: Vector2): co_collider.global_position = pos,
	#)


static func wync_handle_packet_res_client_info(ctx: WyncCtx, data: Variant):

	if data is not WyncPktResClientInfo:
		return 1
	data = data as WyncPktResClientInfo
		
	# check if entity id exists
	# NOTE: is this check enough?
	# NOTE: maybe there's no need to check, because these props can be sync later
	#if not WyncUtils.is_entity_tracked(wync_ctx, data.entity_id):
		#Log.out(self, "Entity %s isn't tracked" % data.entity_id)
		#continue
	
	# set prop ownership
	WyncUtils.prop_set_client_owner(ctx, data.prop_id, data.peer_id)
	Log.out("Prop %s ownership given to client %s" % [data.prop_id, data.peer_id], Log.TAG_WYNC_PEER_SETUP)


static func wync_handle_packet_client_set_lerp_ms(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktClientSetLerpMS:
		return 1
	data = data as WyncPktClientSetLerpMS

	# client and prop exists
	var client_id = WyncUtils.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.err("client %s is not registered" % client_id, Log.TAG_INPUT_RECEIVE)
		return 2

	var client_info := ctx.client_has_info[client_id] as WyncClientInfo
	client_info.lerp_ms = data.lerp_ms

	return OK


static func wync_handle_pkt_clock(ctx: WyncCtx, data: Variant):

	if data is not WyncPktClock:
		return 1
	data = data as WyncPktClock

	var co_ticks = ctx.co_ticks
	var co_predict_data = ctx.co_predict_data
	var curr_time = WyncUtils.clock_get_ms(ctx)
	var physics_fps = ctx.physic_ticks_per_second
	var curr_clock_offset = (data.time + data.latency) - curr_time

	# calculate mean
	# Note: To improve accurace modify _server clock sync_ throttling or sliding window size

	co_predict_data.clock_offset_sliding_window.push(curr_clock_offset)

	var count: int = 0
	var acc: float = 0
	for i: int in range(co_predict_data.clock_offset_sliding_window.size):
		var i_clock_offset = co_predict_data.clock_offset_sliding_window.get_at(i)
		if i_clock_offset == 0:
			continue

		count += 1
		acc += i_clock_offset

	co_predict_data.clock_offset_mean = ceil(acc / count)
	
	# update ticks
	
	var current_server_time: float = curr_time + co_predict_data.clock_offset_mean
	var time_since_packet_sent: float = current_server_time - data.time

	# Note that at the beggining 'server_ticks' will be equal to 0

	var cal_server_ticks = data.tick + ceil(time_since_packet_sent / (1000.0 / physics_fps))
	var new_server_ticks_offset = cal_server_ticks - co_ticks.ticks

	# to avoid fluctuations by one unit, always prefer the biggest value
	if (abs(new_server_ticks_offset - co_ticks.server_tick_offset) == 1):
		new_server_ticks_offset = max(co_ticks.server_tick_offset, new_server_ticks_offset)
	CoTicks.server_tick_offset_collection_add_value(co_ticks, new_server_ticks_offset)
	co_ticks.server_tick_offset = CoTicks.server_tick_offset_collection_get_most_common(co_ticks)
	
	co_ticks.server_ticks = co_ticks.ticks + co_ticks.server_tick_offset

	Log.out("couldn't find input | Servertime %s, real %s, d %s | server_ticks_aprox %s | latency %s | clock %s | %s | %s | %s" % [
		int(current_server_time),
		Time.get_ticks_msec(),
		str(Time.get_ticks_msec() - current_server_time).pad_zeros(2).pad_decimals(1),
		co_ticks.server_ticks,
		Time.get_ticks_msec() - data.time,
		str(co_predict_data.clock_offset_mean).pad_decimals(2),
		str(time_since_packet_sent).pad_decimals(2),
		str(time_since_packet_sent / (1000.0 / physics_fps)).pad_decimals(2),
		co_ticks.server_tick_offset,
	], Log.TAG_CLOCK)


## Call every time a packet is received
static func wync_report_update_received(ctx: WyncCtx):
	if ctx.tick_last_packet_received_from_server == ctx.co_ticks.ticks:
		return

	var tick_rate = ctx.co_ticks.ticks - ctx.tick_last_packet_received_from_server -1
	ctx.server_tick_rate_sliding_window.push(tick_rate)
	ctx.tick_last_packet_received_from_server = ctx.co_ticks.ticks


## Call every time a WyncPktSnap contains _the prob_prop id_
static func wync_try_to_update_prob_prop_rate(ctx: WyncCtx):
	if ctx.low_priority_entity_tick_last_update == ctx.co_ticks.ticks:
		return

	var tick_rate = ctx.co_ticks.ticks - ctx.low_priority_entity_tick_last_update -1
	ctx.low_priority_entity_update_rate_sliding_window.push(tick_rate)
	ctx.low_priority_entity_tick_last_update = ctx.co_ticks.ticks


## Call every physic tick
static func wync_system_calculate_server_tick_rate(ctx: WyncCtx):
	var accumulative = 0
	var amount = 0
	for i in range(ctx.server_tick_rate_sliding_window_size):
		var value = ctx.server_tick_rate_sliding_window.get_at(i)
		if value is not int:
			continue
		accumulative += value
		amount += 1
	if amount <= 0:
		ctx.server_tick_rate = 0
	else:
		ctx.server_tick_rate = accumulative / float(amount)


## Call every physic tick
static func wync_system_calculate_prob_prop_rate(ctx: WyncCtx):
	var accumulative = 0
	var amount = 0
	for i in range(ctx.low_priority_entity_update_rate_sliding_window_size):
		var value = ctx.low_priority_entity_update_rate_sliding_window.get_at(i)
		if value is not int:
			continue
		accumulative += value
		amount += 1
	if amount <= 0:
		ctx.low_priority_entity_update_rate = 0
	else:
		ctx.low_priority_entity_update_rate = accumulative / float(amount)

	# TODO: Move this elsewhere
	# calculate prediction threeshold
	# adding 1 of padding for good measure
	ctx.max_prediction_tick_threeshold = int(ceil(ctx.low_priority_entity_update_rate)) + 1

	# 'REGULAR_PROP_CACHED_STATE_AMOUNT -1' because for xtrap we need to set it
	# to the value just before 'ctx.max_prediction_tick_threeshold -1'
	ctx.max_prediction_tick_threeshold = min(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT-1, ctx.max_prediction_tick_threeshold)


static func wync_dummy_props_cleanup(ctx: WyncCtx):
	# run every few frames
	#if ctx.co_ticks.ticks % 10 != 0:
	if WyncUtils.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
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


## Call after finishing spawning entities
static func wync_system_spawned_props_cleanup(ctx: WyncCtx):
	for i in range(ctx.out_pending_entities_to_spawn.size()-1, -1, -1):
		var entity_to_spawn: WyncCtx.PendingEntityToSpawn = ctx.out_pending_entities_to_spawn[i]
		if entity_to_spawn.already_spawned:
			ctx.out_pending_entities_to_spawn.remove_at(i)


static func wync_system_client_send_delta_prop_acks(ctx: WyncCtx):

	var prop_amount = 0
	var delta_prop_ids: Array[int] = []
	var last_tick_received: Array[int] = []
	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary

	for i in range(ctx.active_prop_ids.size()):
		var prop_id = ctx.active_prop_ids[i]
		var prop := WyncUtils.get_prop(ctx, prop_id)
		assert(prop != null)
		if not prop.relative_syncable:
			continue
		if not delta_props_last_tick.has(prop_id) || delta_props_last_tick[prop_id] == -1:
			continue
		var last_tick = delta_props_last_tick[prop_id]
		delta_prop_ids.append(prop_id)
		last_tick_received.append(last_tick)
		prop_amount += 1

	# build packet and queue
	if prop_amount == 0:
		return

	var packet = WyncPktDeltaPropAck.new()
	packet.prop_amount = prop_amount
	packet.delta_prop_ids = delta_prop_ids
	packet.last_tick_received = last_tick_received

	var result = WyncFlow.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_DELTA_PROP_ACK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)


## client only
## set the latency this client is experimenting (get it from your transport)
## @argument latency_ms: int. Latency in milliseconds
static func wync_client_set_current_latency (ctx: WyncCtx, latency_ms: int):
	ctx.current_tick_nete_latency_ms = latency_ms

static func wync_client_set_physics_ticks_per_second (ctx: WyncCtx, tps: int):
	ctx.physic_ticks_per_second = tps

static func wync_client_set_lerp_ms (ctx: WyncCtx, server_tick_rate: int, lerp_ms: int):
	#var physics_fps: int = ctx.physic_ticks_per_second
	#var server_update_rate: int = ceil((1.0 / (ctx.server_tick_rate + 1)) * physics_fps)
	#ctx.lerp_ms = max(lerp_ms, (1000 / server_update_rate) * 2)

	ctx.co_predict_data.lerp_ms = max(lerp_ms, ceil((1000.0 / server_tick_rate) * 2))
