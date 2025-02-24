class_name WyncFlow


static func wync_tick_start(ctx: WyncCtx):
	# before tick start

	# client
	if WyncUtils.is_client(ctx):
		pass
		#sy_wync_buffered_inputs.on_process([], null, _delta, self)
	
	# server
	else:
		pass


	# increase ticks

	# after tick start


static func wync_feed_packet(ctx: WyncCtx, data: Variant, from_peer: int) -> int:
	# server
	if data is WyncPktJoinRes:
		wync_handle_pkt_join_res(ctx, data)
	elif data is WyncPktEventData:
		wync_handle_pkt_event_data(ctx, data)
	elif data is WyncPktJoinReq:
		wync_handle_pkt_join_req(ctx, data, from_peer)
	elif data is NetPacketInputs:
		wync_handle_net_packet_inputs(ctx, data, from_peer)
	elif data is WyncPktPropSnap:
		wync_handle_pkt_prop_snap(ctx, data)
	elif data is WyncPacketResClientInfo:
		wync_handle_packet_res_client_info(ctx, data)
	else:
		Log.err("Packet not recognized %s skipping" % [data])
		return -1

	# client
	return OK


static func wync_try_to_connect(ctx: WyncCtx) -> int:

	# try get server nete_peer_id
	var server_nete_peer_id = WyncUtils.get_nete_peer_id_from_wync_peer_id(ctx, WyncCtx.SERVER_PEER_ID)
	if server_nete_peer_id == -1:
		return 1

	# send connect req packet
	# TODO: Move this elsewhere
	
	var packet_data = WyncPktJoinReq.new()
	var packet = NetPacket.new()
	packet.to_peer = server_nete_peer_id
	packet.data = packet_data
	ctx.out_packets.append(packet)
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

	Log.out("client nete_peer_id(%s) connected as wync_peer_id(%s)" % [ctx.my_nete_peer_id, ctx.my_peer_id], Log.TAG_WYNC_CONNECT)
	return OK


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
	
		Log.out("events | got this events %s" % [event.event_id], Log.TAG_EVENT_DATA)
		# NOTE: what if we already have this event data? Maybe it's better to receive it anyway?

	return OK


static func wync_handle_pkt_join_req(ctx: WyncCtx, data: Variant, from_peer: int) -> int:

	if data is not WyncPktJoinReq:
		return 1
	data = data as WyncPktJoinReq
	
	# TODO: check it hasn't been setup yet
	# NOTE: the criteria to determine wether a client has a valid prop ownership could be user defined
	# NOTE: wync setup must be ran only once per client
	
	var wync_client_id = WyncUtils.is_peer_registered(ctx, from_peer)
	if wync_client_id != -1:
		Log.out("Client %s already setup in Wync as %s" % [from_peer, wync_client_id], Log.TAG_WYNC_CONNECT)
		return 1
	wync_client_id = WyncUtils.peer_register(ctx, from_peer)
	
	# send confirmation
	
	var packet_data = WyncPktJoinRes.new()
	packet_data.approved = true
	packet_data.wync_client_id = wync_client_id
	
	var packet = NetPacket.new()
	packet.to_peer = from_peer
	packet.data = packet_data
	ctx.out_packets.append(packet)
	
	# NOTE: Maybe move this elsewhere, the client could ask this any time
	# FIXME Harcoded: client 0 -> entity 0 (player)
	packet = make_client_info_packet(ctx, wync_client_id, 0, "input")
	packet.to_peer = from_peer
	ctx.out_packets.append(packet)
	
	packet = make_client_info_packet(ctx, wync_client_id, 0, "events")
	packet.to_peer = from_peer
	ctx.out_packets.append(packet)
	
	# let client own it's global events
	# NOTE: Maybe move this where all channels are defined
	var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	if WyncUtils.is_entity_tracked(ctx, global_events_entity_id):
		packet = make_client_info_packet(ctx, wync_client_id, global_events_entity_id, "channel_0")
		packet.to_peer = from_peer
		ctx.out_packets.append(packet)
	
	else:
		Log.err("Global Event Entity (id %s) for peer_id %s NOT FOUND" % [global_events_entity_id, wync_client_id], Log.TAG_WYNC_CONNECT)

	return OK
	

static func make_client_info_packet(
	ctx: WyncCtx,
	wync_client_id: int,
	entity_id: int,
	prop_name: String) -> NetPacket:
	
	var prop_id = WyncUtils.entity_get_prop_id(ctx, entity_id, prop_name)
	var packet_data = WyncPacketResClientInfo.new()
	packet_data.entity_id = entity_id
	packet_data.prop_id = prop_id
	
	WyncUtils.prop_set_client_owner(ctx, prop_id, wync_client_id)
	Log.out("assigned (entity %s: prop %s) to client %s" % [packet_data.entity_id, prop_id, wync_client_id], Log.TAG_WYNC_CONNECT)
	
	var packet = NetPacket.new()
	packet.data = packet_data
	return packet


static func wync_handle_net_packet_inputs(ctx: WyncCtx, data: Variant, from_peer: int) -> int:

	if data is not NetPacketInputs:
		return 1
	data = data as NetPacketInputs

	# client and prop exists
	var client_id = WyncUtils.is_peer_registered(ctx, from_peer)
	if client_id < 0:
		Log.err("client %s is not registered" % client_id, Log.TAG_INPUT_RECEIVE)
		return 2
	var prop_id = data.prop_id
	if not WyncUtils.prop_exists(ctx, prop_id):
		Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_RECEIVE)
		return 3
	
	# check client has ownership over this prop
	var client_owns_prop = false
	for i_prop_id in ctx.client_owns_prop[client_id]:
		if i_prop_id == prop_id:
			client_owns_prop = true
	if not client_owns_prop:
		return 4
	
	var input_prop = ctx.props[prop_id] as WyncEntityProp
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	for input: NetPacketInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncUtils.duplicate_any(input.data)
		if copy == null:
			Log.out("WARNING: input data can't be duplicated %s" % [input.data], Log.TAG_INPUT_RECEIVE)
		var to_insert = copy if copy != null else input.data
		
		input_prop.confirmed_states.insert_at(input.tick, to_insert)

	return OK


# apply inputs / events to props
# TODO: Better to separate receive/apply logic
# NOTE: could this be merged with SyWyncLatestValue?

static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			if not WyncUtils.prop_exists(ctx, prop_id):
				continue
			var prop = ctx.props[prop_id] as WyncEntityProp
			if not prop:
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

	if data is not WyncPktPropSnap:
		return 1
	data = data as WyncPktPropSnap
	
	for snap: WyncPktPropSnap.EntitySnap in data.snaps:
		
		if not WyncUtils.is_entity_tracked(ctx, snap.entity_id):
			Log.err("couldn't find entity (%s) skipping..." % [snap.entity_id], Log.TAG_LATEST_VALUE)
			continue
		
		for prop: WyncPktPropSnap.PropSnap in snap.props:
			
			var local_prop = WyncUtils.get_prop(ctx, prop.prop_id)
			if local_prop == null:
				Log.err("couldn't find prop (%s) skipping..." % [prop.prop_id], Log.TAG_LATEST_VALUE)
				continue
			local_prop = local_prop as WyncEntityProp
			if local_prop.relative_syncable:
				continue
			
			# NOTE: two tick datas could have arrive at the same tick
			local_prop.last_ticks_received.push(data.tick)
			local_prop.confirmed_states.insert_at(data.tick, prop.prop_value)
			local_prop.arrived_at_tick.insert_at(data.tick, ctx.co_ticks.ticks)
			local_prop.just_received_new_state = true

			if local_prop.is_auxiliar_prop:
				# notify _main delta prop_ about the updates
				var delta_prop = WyncUtils.get_prop(ctx, local_prop.auxiliar_delta_events_prop_id) as WyncEntityProp
				delta_prop.just_received_new_state = true


		# process relative syncable separatedly for now to reason about them separatedly

		for prop: WyncPktPropSnap.PropSnap in snap.props:
			
			var local_prop = WyncUtils.get_prop(ctx, prop.prop_id)
			if local_prop == null:
				Log.err("couldn't find prop (%s) skipping..." % [prop.prop_id], Log.TAG_LATEST_VALUE)
				continue
			local_prop = local_prop as WyncEntityProp
			if not local_prop.relative_syncable:
				continue

			# TODO: overwrite real data, clear all delta events, etc.
			# if a _predicted delta prop_ receives fullsnapshot cleanup must be done
			# if a delta prop receives a fullsnapshot we have no other option but to comply

			local_prop.setter.call(prop.prop_value)
			local_prop.just_received_new_state = true
			var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
			delta_props_last_tick[prop.prop_id] = data.tick
			Log.out("delta sync debug1 | ser_tick(%s) delta_prop_last_tick %s" % [ctx.co_ticks.server_ticks, delta_props_last_tick], Log.TAG_LATEST_VALUE)

			# TODO: reset event buffer, clean events that should already be applied by this tick
			# Reset it but only for one prop
			# SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(ctx)

	# update last tick received
	ctx.last_tick_received = max(ctx.last_tick_received, data.tick)


static func wync_handle_packet_res_client_info(ctx: WyncCtx, data: Variant):

	if data is not WyncPacketResClientInfo:
		return 1
	data = data as WyncPacketResClientInfo
		
	# check if entity id exists
	# NOTE: is this check enough?
	# NOTE: maybe there's no need to check, because these props can be sync later
	#if not WyncUtils.is_entity_tracked(wync_ctx, data.entity_id):
		#Log.out(self, "Entity %s isn't tracked" % data.entity_id)
		#continue
	
	# set prop ownership
	WyncUtils.prop_set_client_owner(ctx, data.prop_id, ctx.my_peer_id)
	Log.out("Prop %s ownership given to client %s" % [data.prop_id, ctx.my_peer_id], Log.TAG_WYNC_PEER_SETUP)
