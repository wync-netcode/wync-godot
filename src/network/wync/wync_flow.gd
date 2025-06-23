class_name WyncFlow

## High level functions related to logic cycles


## Note. Before running this, make sure to receive packets from the network

static func wync_server_tick_start(ctx: WyncCtx):

	WyncClock.wync_advance_ticks(ctx)

	WyncEventUtils.module_events_consumed_advance_tick(ctx)

	WyncWrapper.wync_input_props_set_tick_value(ctx)

	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)


static func wync_server_tick_end(ctx: WyncCtx):
	for peer_id: int in range(1, ctx.peers.size()):
		WyncClock.wync_system_stabilize_latency(ctx, ctx.peer_latency_info[peer_id])

	WyncXtrap.wync_server_filter_prop_ids(ctx)

	WyncStateSend.system_update_delta_base_state_tick(ctx)

	# NOTE: maybe a way to extract data but only events, since that is unskippable?
	# This function extracts regular props, plus _auxiliar delta event props_
	# We need a function to extract data exclusively of events... Like the equivalent
	# of the client's _input_bufferer_
	WyncWrapper.extract_data_to_tick(ctx, ctx.co_ticks.ticks)


static func wync_client_tick_end(ctx: WyncCtx):

	WyncXtrap.wync_client_filter_prop_ids(ctx)
	WyncClock.wync_advance_ticks(ctx)
	WyncClock.wync_system_stabilize_latency(ctx, ctx.peer_latency_info[WyncCtx.SERVER_PEER_ID])
	WyncClock.wync_update_prediction_ticks(ctx)
	
	WyncWrapper.wync_buffer_inputs(ctx)

	# CANNOT reset events BEFORE polling inputs, WHERE do we put this?
	
	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)
	WyncDeltaSyncUtils.predicted_event_props_clear_events(ctx)

	WyncStateSet.wync_reset_props_to_latest_value(ctx)
	
	# NOTE: Maybe this one should be called AFTER consuming packets, and BEFORE xtrap
	WyncStats.wync_system_calculate_prob_prop_rate(ctx)

	WyncStats.wync_system_calculate_server_tick_rate(ctx)

	WyncStateStore.wync_service_cleanup_dummy_props(ctx)

	WyncLerp.wync_lerp_precompute(ctx)


## Calls all the systems that produce packets to send whilst respecting the data limit

static func wync_system_gather_packets(ctx: WyncCtx):

	if ctx.is_client:
		if not ctx.connected:
			WyncJoin.service_wync_try_to_connect(ctx)                     # reliable, commited
		else:
			WyncClock.wync_client_ask_for_clock(ctx)      # unreliable
			WyncDeltaSyncUtils.wync_system_client_send_delta_prop_acks(ctx) # unreliable
			WyncStateSend.wync_client_send_inputs(ctx)         # unreliable
			WyncEventUtils.wync_send_event_data(ctx)         # reliable, commited

	else:
		WyncSpawn.wync_system_send_entities_to_despawn(ctx) # reliable, commited
		WyncSpawn.wync_system_send_entities_to_spawn(ctx)   # reliable, commited
		WyncInput.wync_system_sync_client_ownership(ctx)       # reliable, commited

		WyncThrottle.wync_system_fill_entity_sync_queue(ctx)
		WyncThrottle.wync_compute_entity_sync_order(ctx)
		WyncStateSend.wync_send_extracted_data(ctx) # both reliable/unreliable

	WyncStats.wync_system_calculate_data_per_tick(ctx)


static func wync_feed_packet(ctx: WyncCtx, wync_pkt: WyncPacket, from_nete_peer_id: int) -> int:

	# debug statistics
	WyncDebug.log_packet_received(ctx, wync_pkt.packet_type_id)
	var is_client = ctx.is_client

	# tick rate calculation	
	if is_client:
		WyncStats._wync_report_update_received(ctx)
		#Log.outc(ctx, "tagtps | tag1 | tick(%s) received packet %s" % [ctx.co_ticks.ticks, WyncPacket.PKT_NAMES[wync_pkt.packet_type_id]])
	#else:
		#Log.outc(ctx, "setted | tick(%s) received packet %s" % [ctx.co_ticks.ticks, WyncPacket.PKT_NAMES[wync_pkt.packet_type_id]])

	match wync_pkt.packet_type_id:
		WyncPacket.WYNC_PKT_JOIN_REQ:
			if not is_client:
				WyncJoin.wync_handle_pkt_join_req(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_JOIN_RES:
			if is_client:
				WyncJoin.wync_handle_pkt_join_res(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_EVENT_DATA:
			WyncEventUtils.wync_handle_pkt_event_data(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_INPUTS:
			if is_client:
				WyncStateStore.wync_client_handle_pkt_inputs(ctx, wync_pkt.data)
			else:
				WyncStateStore.wync_server_handle_pkt_inputs(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_PROP_SNAP:
			if is_client:
				# TODO: in the future we might support client authority
				WyncStateStore.wync_handle_pkt_prop_snap(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_RES_CLIENT_INFO:
			if is_client:
				WyncJoin.wync_handle_packet_res_client_info(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_CLOCK:
			if is_client:
				WyncClock.wync_handle_pkt_clock(ctx, wync_pkt.data)
			else:
				WyncClock.wync_server_handle_clock_req(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_CLIENT_SET_LERP_MS:
			if not is_client:
				WyncLerp.wync_handle_packet_client_set_lerp_ms(ctx, wync_pkt.data, from_nete_peer_id)
		WyncPacket.WYNC_PKT_SPAWN:
			if is_client:
				Log.outc(ctx, "spawn, spawn pkt %s" % [(wync_pkt.data as WyncPktSpawn).entity_ids])
				WyncSpawn.wync_handle_pkt_spawn(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_DESPAWN:
			if is_client:
				Log.outc(ctx, "spawn, despawn pkt %s" % [(wync_pkt.data as WyncPktDespawn).entity_ids])
				WyncSpawn.wync_handle_pkt_despawn(ctx, wync_pkt.data)
		WyncPacket.WYNC_PKT_DELTA_PROP_ACK:
			if not is_client:
				WyncDeltaSyncUtils.wync_handle_pkt_delta_prop_ack(ctx, wync_pkt.data, from_nete_peer_id)
		_:
			Log.err("wync packet_type_id(%s) not recognized skipping (%s)" % [wync_pkt.packet_type_id, wync_pkt.data])
			return -1

	return OK

# Setup functions
# ================================================================

static func server_setup(ctx: WyncCtx) -> int:
	# peer id 0 reserved for server
	ctx.is_client = false
	ctx.my_peer_id = 0
	ctx.peers.resize(1)
	ctx.peers[ctx.my_peer_id] = -1
	ctx.connected = true

	# setup event caching
	ctx.events_hash_to_id.init(ctx.max_amount_cache_events)
	ctx.to_peers_i_sent_events = []
	ctx.to_peers_i_sent_events.resize(ctx.max_peers)
	for i in range(ctx.max_peers):
		ctx.to_peers_i_sent_events[i] = FIFOMap.new()
		ctx.to_peers_i_sent_events[i].init(ctx.max_amount_cache_events)

	# setup relative synchronization
	ctx.peers_events_to_sync = []
	ctx.peers_events_to_sync.resize(ctx.max_peers)
	for i in range(ctx.max_peers):
		ctx.peers_events_to_sync[i] = {} as Dictionary

	# setup peer channels
	WyncEventUtils.setup_peer_global_events(ctx, WyncCtx.SERVER_PEER_ID)
	for i in range(1, ctx.max_peers):
		WyncEventUtils.setup_peer_global_events(ctx, i)

	# setup prob prop
	WyncStats.setup_entity_prob_for_entity_update_delay_ticks(ctx, WyncCtx.SERVER_PEER_ID)

	return 0


static func client_init(ctx: WyncCtx) -> int:
	ctx.is_client = true
	return OK
