class_name WyncFlow


static func wync_server_tick_start(ctx: WyncCtx):
	# before tick start

	SyTicks.wync_advance_ticks(ctx)

	# after tick start

	WyncFlow.wync_input_props_set_tick_value(ctx)

	SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(ctx)

	SyWyncTickStartAfter.predicted_props_clear_events(ctx)


static func wync_server_tick_end(ctx: WyncCtx):
	SyWyncStateExtractor.update_delta_base_state_tick(ctx)

	# NOTE: maybe a way to extract data but only events, since that is unskippable?
	# This function extracts regular props, plus _auxiliar delta event props_
	# We need a function to extract data exclusively of events... Like the equivalent
	# of the client's _input_bufferer_
	SyWyncStateExtractor.extract_data_to_tick(ctx, ctx.co_ticks, ctx.co_ticks.ticks)

	# basic throttling here
	#if ctx.co_ticks.ticks % 4 != 0:
		#return

	# move to gather reliable packets
	SyWyncClockServer.wync_server_sync_clock(ctx)

	# send

	WyncThrottle.wync_system_fill_entity_sync_queue(ctx)
	WyncThrottle.wync_compute_entity_sync_order(ctx)
	SyWyncStateExtractor.wync_send_extracted_data(ctx)

	

	#"""
	# regular extractor
	#SyWyncStateExtractor.extract_data_to_tick(ctx, ctx.co_ticks, ctx.co_ticks.ticks)
	#SyWyncStateExtractor.wync_send_extracted_data(ctx)
	## delta extractor
	#SyWyncStateExtractorDeltaSync.wync_reset_events_to_sync(ctx)
	## these two must be called in this order:
	#SyWyncStateExtractorDeltaSync.queue_delta_event_data_to_be_synced_to_peers(ctx)
	#SyWyncSendEventData.wync_send_event_data (ctx)
	#WyncThrottle.wync_system_send_entities_to_spawn(ctx)
	#"""

	#TODO : WyncThrottle.wync_system_send_entities_updates(ctx)


static func wync_client_tick_start(ctx: WyncCtx):
	
	# before tick start

	SyWyncBufferedInputs.wync_buffer_inputs(ctx)

	SyTicks.wync_advance_ticks(ctx)

	# after tick start

	# sy_wync_receive_event_data.on_process([], null, _delta, self)

	# NOTE: Maybe this one should be called AFTER consuming packets, and BEFORE xtrap
	wync_system_calculate_prob_prop_rate(ctx)

	wync_system_calculate_server_tick_rate(ctx)

	SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(ctx)

	SyWyncTickStartAfter.predicted_props_clear_events(ctx)

	# SyUserWyncConsumePacketsSecond # consume packets would go after this function

	WyncFlow.wync_try_to_connect(ctx)

	# SyWyncReceiveClientInfo


static func wync_client_tick_middle(ctx: WyncCtx):

	# SyUserWyncConsumePackets

	# SyNetLatencyStable
	# WyncFlow.wync_client_set_current_latency (single_wync.ctx, co_loopback.latency)
	# wync_stabilize_latency (single_wync.ctx)

	SyNetLatencyStable.wync_stabilize_latency(ctx)

	SyNetPredictionTicks.wync_update_prediction_ticks(ctx)

	SyWyncBufferedInputs.wync_buffer_inputs(ctx)

	# SyWyncSaveConfirmedStates
	# WyncFlow.wync_handle_pkt_prop_snap(wync_ctx, data)

	SyWyncLatestValue.wync_reset_props_to_latest_value(ctx)

	# Xtrap
	#Log.outc(ctx, "debug_pred_delta_event XTRAP START")


static func wync_client_tick_end(ctx: WyncCtx):

	SyWyncSendInputs.wync_client_send_inputs(ctx)

	SyWyncSendEventData.wync_send_event_data(ctx)

	SyWyncLerpPrecompute.wync_lerp_precompute(ctx)


static func wync_feed_packet(ctx: WyncCtx, wync_pkt: WyncPacket, from_nete_peer_id: int) -> int:

	# debug statistics
	WyncDebug.log_packet_received(ctx, wync_pkt.packet_type_id)
	var is_client = WyncUtils.is_client(ctx)

	# tick rate calculation	
	if is_client:
		wync_report_update_received(ctx)
		#Log.outc(ctx, "tagtps | tag1 | tick(%s) received packet %s" % [ctx.co_ticks.ticks, WyncPacket.PKT_NAMES[wync_pkt.packet_type_id]])

	match wync_pkt.packet_type_id:
		WyncPacket.WYNC_PKT_JOIN_REQ:
			if not is_client:
				wync_handle_pkt_join_req(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_JOIN_RES:
			# TODO: run only if it's is_client
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
	if ctx.co_ticks.ticks % 5 != 0:
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
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, true)

	var packet_data_lerp := WyncPktClientSetLerpMS.new()
	packet_data_lerp.lerp_ms = ctx.co_predict_data.lerp_ms
	result = wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_CLIENT_SET_LERP_MS, packet_data_lerp)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, true)
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
		wync_event.data.arg_count = event.arg_count
		wync_event.data.arg_data_type = event.arg_data_type.duplicate(true)
		wync_event.data.arg_data = event.arg_data # std::move(std::unique_pointer)
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
		WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], true)
	
	# NOTE: Maybe move this elsewhere, the client could ask this any time
	# FIXME Harcoded: client 0 -> entity 0 (player)

	var packet_info: WyncPktResClientInfo
	packet_info = make_client_info_packet(ctx, wync_client_id, 0, "input")
	result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet_info)
	if result[0] == OK:
		WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], true)

	packet_info = make_client_info_packet(ctx, wync_client_id, 0, "events")
	result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet_info)
	if result[0] == OK:
		WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], true)
	
	# let client own it's global events
	# NOTE: Maybe move this where all channels are defined

	var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	if WyncUtils.is_entity_tracked(ctx, global_events_entity_id):

		packet_info = make_client_info_packet(ctx, wync_client_id, global_events_entity_id, "channel_0")
		result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet_info)
		if result[0] == OK:
			WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], true)
	
	else:
		Log.err("Global Event Entity (id %s) for peer_id %s NOT FOUND" % [global_events_entity_id, wync_client_id], Log.TAG_WYNC_CONNECT)

	return OK
	

static func make_client_info_packet(
	ctx: WyncCtx,
	wync_client_id: int,
	entity_id: int,
	prop_name: String) -> WyncPktResClientInfo:
	
	var prop_id = WyncUtils.entity_get_prop_id(ctx, entity_id, prop_name)
	var packet_data = WyncPktResClientInfo.new()
	packet_data.entity_id = entity_id
	packet_data.prop_id = prop_id
	
	WyncUtils.prop_set_client_owner(ctx, prop_id, wync_client_id)
	Log.out("assigned (entity %s: prop %s) to client %s" % [packet_data.entity_id, prop_id, wync_client_id], Log.TAG_WYNC_CONNECT)
	
	return packet_data


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
		var to_insert = copy if copy != null else input.data
		
		input_prop.confirmed_states.insert_at(input.tick, to_insert)

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
		
			# FIXME: check the tick with a wrapper/decorator class for inputs to avoid using old values
			var input = prop.confirmed_states.get_at(ctx.co_ticks.ticks)
			if input == null:
				continue
			prop.setter.call(input)
			#Log.out(self, "input is %s,%s" % [input.movement_dir.x, input.movement_dir.y])

	return OK


static func wync_handle_pkt_prop_snap(ctx: WyncCtx, data: Variant):

	if data is not WyncPktSnap:
		return 1
	data = data as WyncPktSnap

	for snap_prop: WyncPktSnap.SnapProp in data.snaps:

		WyncDebug.packet_received_log_prop_id(ctx, WyncPacket.WYNC_PKT_PROP_SNAP, snap_prop.prop_id)

		var prop = WyncUtils.get_prop(ctx, snap_prop.prop_id)
		if prop == null:
			Log.err("couldn't find prop (%s) skipping..." % [snap_prop.prop_id], Log.TAG_LATEST_VALUE)
			continue
		prop = prop as WyncEntityProp
		if prop.relative_syncable:
			continue
		
		# NOTE: two tick datas could have arrive at the same tick
		prop.last_ticks_received.push(data.tick)
		prop.confirmed_states.insert_at(data.tick, snap_prop.state)
		prop.arrived_at_tick.insert_at(data.tick, ctx.co_ticks.ticks)
		prop.just_received_new_state = true

		if prop.is_auxiliar_prop:
			# notify _main delta prop_ about the updates
			var delta_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id) as WyncEntityProp
			delta_prop.just_received_new_state = true

		# update prob prop update rate
		if snap_prop.prop_id == ctx.PROP_ID_PROB:
			wync_try_to_update_prob_prop_rate(ctx)


	# process relative syncable separatedly for now to reason about them separatedly

	for snap_prop: WyncPktSnap.SnapProp in data.snaps:
		
		var prop = WyncUtils.get_prop(ctx, snap_prop.prop_id)
		if prop == null:
			Log.err("couldn't find prop (%s) skipping..." % [snap_prop.prop_id], Log.TAG_LATEST_VALUE)
			continue

		prop = prop as WyncEntityProp
		if not prop.relative_syncable:
			continue

		# TODO: overwrite real data, clear all delta events, etc.
		# if a _predicted delta prop_ receives fullsnapshot cleanup must be done
		# if a delta prop receives a fullsnapshot we have no other option but to comply

		prop.setter.call(snap_prop.state)
		prop.just_received_new_state = true
		var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
		delta_props_last_tick[snap_prop.prop_id] = data.tick
		#Log.out("debug_pred_delta_event | ser_tick(%s) delta_prop_last_tick %s" % [ctx.co_ticks.server_ticks, delta_props_last_tick], Log.TAG_LATEST_VALUE)

		# clean up predicted data TODO

		if WyncUtils.prop_is_predicted(ctx, snap_prop.prop_id):

			# get aux_prop and clean the confirmed_states_undo
			var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
			for j in range(ctx.first_tick_predicted, ctx.last_tick_predicted +1):
				aux_prop.confirmed_states.insert_at(j, [] as Array[int])
				aux_prop.confirmed_states_undo.insert_at(j, [] as Array[int])

			# debugging: save canonic state to compare it later
			var state_dup = WyncUtils.duplicate_any(prop.getter.call())
			prop.confirmed_states.insert_at(0, state_dup)

	wync_client_update_last_tick_received(ctx, data.tick)


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
	WyncUtils.prop_set_client_owner(ctx, data.prop_id, ctx.my_peer_id)
	Log.out("Prop %s ownership given to client %s" % [data.prop_id, ctx.my_peer_id], Log.TAG_WYNC_PEER_SETUP)


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

	var co_predict_data = ctx.co_predict_data
	var co_ticks = ctx.co_ticks
	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second
	var server_time_diff = (data.time + data.latency) - curr_time

	# calculate mean
	
	co_predict_data.clock_packets_received += 1
	co_predict_data.clock_offset_accumulator += server_time_diff
	co_predict_data.clock_offset_mean = (co_predict_data.clock_offset_mean * (co_predict_data.clock_packets_received-1) + server_time_diff) / co_predict_data.clock_packets_received
	
	# update ticks
	
	var current_server_time: float = curr_time + co_predict_data.clock_offset_mean
	var time_since_packet_sent: float = current_server_time - data.time
	
	if co_predict_data.clock_packets_received < 11:
		co_ticks.server_ticks = data.tick \
		+ round(time_since_packet_sent / (1000.0 / physics_fps))
		co_ticks.server_ticks_offset = co_ticks.server_ticks - co_ticks.ticks
		
	elif not co_ticks.server_ticks_offset_initialized:
		co_ticks.server_ticks_offset_initialized = true
		co_ticks.server_ticks = co_ticks.ticks + co_ticks.server_ticks_offset
		# TODO: Allow for updating co_ticks.server_ticks_offset every minute or so

	Log.out("Servertime %s, real %s, d %s | server_ticks_aprox %s | latency %s | clock %s | %s | %s | %s" % [
		int(current_server_time),
		Time.get_ticks_msec(),
		str(Time.get_ticks_msec() - current_server_time).pad_zeros(2).pad_decimals(1),
		co_ticks.server_ticks,
		Time.get_ticks_msec() - data.time,
		str(co_predict_data.clock_offset_mean).pad_decimals(2),
		str(time_since_packet_sent).pad_decimals(2),
		str(time_since_packet_sent / (1000.0 / physics_fps)).pad_decimals(2),
		co_ticks.server_ticks_offset,
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
