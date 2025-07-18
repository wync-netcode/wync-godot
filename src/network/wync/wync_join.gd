class_name WyncJoin


static func service_wync_try_to_connect(ctx: WyncCtx) -> int:
	if ctx.connected:
		return OK

	# throttle
	if WyncMisc.fast_modulus(ctx.co_ticks.ticks, 8) != 0:
		return OK

	# try get server nete_peer_id
	var server_nete_peer_id = WyncJoin.get_nete_peer_id_from_wync_peer_id(ctx, WyncCtx.SERVER_PEER_ID)
	if server_nete_peer_id == -1:
		return 1

	# send connect req packet
	# TODO: Move this elsewhere
	
	var packet_data := WyncPktJoinReq.new()
	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_JOIN_REQ, packet_data)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)

	# TODO: Ser lerpms could be moved somewhere else, since it could be sent anytime

	var packet_data_lerp := WyncPktClientSetLerpMS.new()
	packet_data_lerp.lerp_ms = ctx.co_predict_data.lerp_ms
	result = WyncPacketUtil.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_CLIENT_SET_LERP_MS, packet_data_lerp)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)
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
	WyncJoin.client_setup_my_client(ctx, data.wync_client_id)

	Log.out("client nete_peer_id(%s) connected as wync_peer_id(%s)" % [ctx.my_nete_peer_id, ctx.my_peer_id], Log.TAG_WYNC_CONNECT, Log.TAG_DEBUG2)
	return OK


## This systems writes state
static func wync_handle_pkt_join_req(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktJoinReq:
		return 1
	data = data as WyncPktJoinReq
	
	# TODO: check it hasn't been setup yet
	# NOTE: the criteria to determine wether a client has a valid prop ownership could be user defined
	# NOTE: wync setup must be ran only once per client
	
	var wync_client_id = WyncJoin.is_peer_registered(ctx, from_nete_peer_id)
	if wync_client_id != -1:
		Log.out("Client %s already setup in Wync as %s" % [from_nete_peer_id, wync_client_id], Log.TAG_WYNC_CONNECT)
		return 1
	wync_client_id = WyncJoin.peer_register(ctx, from_nete_peer_id)
	
	# send confirmation
	
	var packet = WyncPktJoinRes.new()
	packet.approved = true
	packet.wync_client_id = wync_client_id
	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_JOIN_RES, packet)
	if result[0] == OK:
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, result[1], WyncCtx.RELIABLE, true)

	# let client own it's own global events
	# NOTE: Maybe move this where all channels are defined

	# WARNING: TODO: REFACTOR
	var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	var prop_id = WyncTrack.entity_get_prop_id(ctx, global_events_entity_id, "channel_0")
	assert(prop_id != -1)
	WyncInput.prop_set_client_owner(ctx, prop_id, wync_client_id)

	#var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	#if WyncTrack.is_entity_tracked(ctx, global_events_entity_id):

		#var packet_info = make_client_info_packet(ctx, wync_client_id, global_events_entity_id, "channel_0")
		#result = wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet_info)
		#if result[0] == OK:
			#WyncThrottle.wync_try_to_queue_out_packet(ctx, result[1], WyncCtx.RELIABLE, true)
	
	#else:
		#Log.err("Global Event Entity (id %s) for peer_id %s NOT FOUND" % [global_events_entity_id, wync_client_id], Log.TAG_WYNC_CONNECT)

	# queue as pending for setup

	ctx.out_peer_pending_to_setup.append(from_nete_peer_id)

	return OK
	

static func wync_handle_packet_res_client_info(ctx: WyncCtx, data: Variant):

	if data is not WyncPktResClientInfo:
		return 1
	data = data as WyncPktResClientInfo
		
	# check if entity id exists
	# NOTE: is this check enough?
	# NOTE: maybe there's no need to check, because these props can be sync later
	#if not WyncTrack.is_entity_tracked(wync_ctx, data.entity_id):
		#Log.out(self, "Entity %s isn't tracked" % data.entity_id)
		#continue
	
	# set prop ownership
	WyncInput.prop_set_client_owner(ctx, data.prop_id, data.peer_id)
	Log.out("Prop %s ownership given to client %s" % [data.prop_id, data.peer_id], Log.TAG_WYNC_PEER_SETUP)

	# recompute filtered props
	ctx.was_any_prop_added_deleted = true


## Server side function
## @argument peer_data (optional): store a custom int if needed. Use it to save an external identifier. This is usually the transport's peer_id
 
static func peer_register(ctx: WyncCtx, peer_data: int = -1) -> int:
	var peer_id = ctx.peers.size()
	ctx.peers.append(peer_data)
	ctx.client_owns_prop[peer_id] = []
	ctx.client_has_relative_prop_has_last_tick[peer_id] = {}
	
	ctx.client_has_info[peer_id] = WyncClientInfo.new()

	return peer_id


## @returns int: peer_id if found; -1 if not found
static func is_peer_registered(ctx: WyncCtx, nete_peer_id: int) -> int:
	for peer_id: int in range(ctx.peers.size()):
		var i_peer_data = ctx.peers[peer_id]
		if i_peer_data == nete_peer_id:
			return peer_id
	return -1


## @returns int: peer_id if found; -1 if not found
static func get_wync_peer_id_from_nete_peer_id(ctx: WyncCtx, nete_peer_id: int) -> int:
	return is_peer_registered(ctx, nete_peer_id)


static func wync_set_my_nete_peer_id (ctx: WyncCtx, nete_peer_id: int) -> int:
	ctx.my_nete_peer_id = nete_peer_id
	return OK


## Client only
static func wync_set_server_nete_peer_id (ctx: WyncCtx, nete_peer_id: int) -> int:
	if ctx.peers.size() == 0:
		ctx.peers.resize(1)
	ctx.peers[0] = nete_peer_id
	ctx.my_nete_peer_id = nete_peer_id
	return OK


## Gets nete_peer_id from a given wync_peer_id
## Used to know to whom to send packets
## @returns int: nete_peer_id if found; -1 if not found
static func get_nete_peer_id_from_wync_peer_id (ctx: WyncCtx, wync_peer_id: int) -> int:
	if wync_peer_id >= 0 && wync_peer_id < ctx.peers.size():
		return ctx.peers[wync_peer_id]
	return -1


## Client side function

static func client_setup_my_client(ctx: WyncCtx, peer_id: int) -> bool:
	ctx.my_peer_id = peer_id

	# we might have received WYNC_PKT_RES_CLIENT_INFO before
	if not ctx.client_owns_prop.has(peer_id):
		ctx.client_owns_prop[peer_id] = []

	# setup event caching
	ctx.events_hash_to_id.init(ctx.max_amount_cache_events)
	ctx.to_peers_i_sent_events = []
	ctx.to_peers_i_sent_events.resize(1)
	ctx.to_peers_i_sent_events[ctx.SERVER_PEER_ID] = FIFOMap.new()
	ctx.to_peers_i_sent_events[ctx.SERVER_PEER_ID].init(ctx.max_amount_cache_events)

	# setup relative synchronization
	ctx.peers_events_to_sync = []
	ctx.peers_events_to_sync.resize(1)
	ctx.peers_events_to_sync[ctx.SERVER_PEER_ID] = {} as Dictionary

	# setup peer channels
	WyncEventUtils.setup_peer_global_events(ctx, WyncCtx.SERVER_PEER_ID)
	for i in range(1, ctx.max_peers):
		WyncEventUtils.setup_peer_global_events(ctx, i)
	
	# setup server global events
	#WyncTrack.setup_peer_global_events(ctx, ctx.SERVER_PEER_ID)
	# setup own global events
	#WyncTrack.setup_peer_global_events(ctx, ctx.my_peer_id)
	# setup prob prop
	WyncStats.setup_entity_prob_for_entity_update_delay_ticks(ctx, ctx.my_peer_id)

	return true


static func clear_peers_pending_to_setup(ctx: WyncCtx):
	ctx.out_peer_pending_to_setup.clear()


static func out_client_just_connected_to_server(ctx: WyncCtx) -> bool:
	var just_connected: bool = ctx.connected && not ctx._prev_connected
	ctx._prev_connected = ctx.connected
	return just_connected
