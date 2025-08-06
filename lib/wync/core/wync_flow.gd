class_name WyncFlow


# ==================================================
# PUBLIC API
# ==================================================

## High level functions related to logic cycles


static func _internal_setup_context(ctx: WyncCtx):

	ctx.common = WyncCtx.CoCommon.new()
	ctx.wrapper = WyncWrapperStructs.WyncWrapperCtx.new()

	ctx.co_track = WyncCtx.CoStateTrackingCommon.new()
	ctx.co_events = WyncCtx.CoEvents.new()
	ctx.co_clientauth = WyncCtx.CoClientAuthority.new()
	ctx.co_metrics = WyncCtx.CoMetrics.new()
	ctx.co_spawn = WyncCtx.CoSpawn.new()

	## Server only

	ctx.co_throttling = WyncCtx.CoThrottling.new()
	ctx.co_filter_s = WyncCtx.CoFilterServer.new()

	## Client only

	ctx.co_ticks = WyncCtx.CoTicks.new()
	ctx.co_pred = WyncCtx.CoPredictionData.new()
	ctx.co_lerp = WyncCtx.CoLerp.new()
	ctx.co_dummy = WyncCtx.CoDummyProps.new()
	ctx.co_filter_c = WyncCtx.CoFilterClient.new()


	CoTicksUtils.init_co_ticks(ctx.co_ticks)
	CoTicksUtils.init_co_prediction_data(ctx.co_pred)

	ctx.co_track.props.resize(ctx.MAX_PROPS)
	ctx.co_track.prop_id_cursor = 0
	ctx.co_track.active_prop_ids = []

	var max_peers = ctx.common.max_peers
	var max_channels = ctx.common.max_channels

	ctx.co_events.peer_has_channel_has_events.resize(max_peers)
	ctx.co_events.prop_id_by_peer_by_channel.resize(max_peers)
	ctx.co_track.client_has_relative_prop_has_last_tick.resize(max_peers) # NOTE: index 0 not used
	ctx.co_spawn.out_queue_spawn_events = FIFORingAny.new(1024)

	ctx.co_throttling.queue_clients_entities_to_sync.resize(max_peers)
	ctx.co_throttling.queue_entity_pairs_to_sync.resize(100)

	ctx.co_throttling.clients_sees_entities.resize(max_peers)
	ctx.co_throttling.clients_sees_new_entities.resize(max_peers)
	ctx.co_throttling.clients_no_longer_sees_entities.resize(max_peers)
	ctx.co_throttling.entities_synced_last_time.resize(max_peers)

	ctx.co_throttling.clients_cached_unreliable_snapshots.resize(max_peers)
	ctx.co_throttling.clients_cached_reliable_snapshots.resize(max_peers)

	ctx.common.peer_latency_info.resize(max_peers)

	for peer_i in range(max_peers):
		ctx.co_events.peer_has_channel_has_events[peer_i] = []
		ctx.co_events.peer_has_channel_has_events[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			ctx.co_events.peer_has_channel_has_events[peer_i][channel_i] = []
		ctx.co_track.client_has_relative_prop_has_last_tick[peer_i] = {}

		ctx.co_events.prop_id_by_peer_by_channel[peer_i] = []
		ctx.co_events.prop_id_by_peer_by_channel[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			ctx.co_events.prop_id_by_peer_by_channel[peer_i][channel_i] = -1

		#if peer_i != WyncCtx.SERVER_PEER_ID:
		ctx.co_throttling.queue_clients_entities_to_sync[peer_i] = FIFORing.new()
		ctx.co_throttling.queue_clients_entities_to_sync[peer_i].init(128) # TODO: Make this user defined
		ctx.co_throttling.clients_sees_entities[peer_i] = {}
		ctx.co_throttling.clients_sees_new_entities[peer_i] = {}
		ctx.co_throttling.clients_no_longer_sees_entities[peer_i] = {}
		ctx.co_throttling.entities_synced_last_time[peer_i] = {}

		var latency_info = WyncCtx.PeerLatencyInfo.new()
		latency_info.latency_buffer.resize(WyncCtx.LATENCY_BUFFER_SIZE)
		ctx.common.peer_latency_info[peer_i] = latency_info

		ctx.co_throttling.clients_cached_reliable_snapshots[peer_i] = [] as Array[WyncPktSnap.SnapProp]
		ctx.co_throttling.clients_cached_unreliable_snapshots[peer_i] = [] as Array[WyncPktSnap.SnapProp]
	
	ctx.co_pred.tick_action_history = RingBuffer.new(ctx.co_pred.tick_action_history_size, {})
	for i in range(ctx.co_pred.tick_action_history_size):
		ctx.co_pred.tick_action_history.insert_at(i, {} as Dictionary)
	
	ctx.common.client_has_info.resize(max_peers)

	ctx.co_metrics.debug_packets_received.resize(WyncPacket.WYNC_PKT_AMOUNT)
	for i in range(WyncPacket.WYNC_PKT_AMOUNT):
		ctx.co_metrics.debug_packets_received[i] = [] as Array[int]
		ctx.co_metrics.debug_packets_received[i].resize(20) # amount of co_track.props, also 0 is reserved for 'total'

	ctx.co_metrics.debug_data_per_tick_sliding_window = RingBuffer.new(ctx.co_metrics.debug_data_per_tick_sliding_window_size, 0)

	ctx.co_metrics.server_tick_rate_sliding_window = RingBuffer.new(ctx.SERVER_TICK_RATE_SLIDING_WINDOW_SIZE, 0)

	ctx.co_metrics.low_priority_entity_update_rate_sliding_window = RingBuffer.new(ctx.co_metrics.low_priority_entity_update_rate_sliding_window_size, 0)

	ctx.co_dummy.dummy_props = {}

	ctx.co_lerp.max_lerp_factor_symmetric = 1.0


## Calls all the systems that produce packets to send whilst respecting the data limit

static func _internal_wync_system_gather_packets_start(ctx: WyncCtx):
	if ctx.common.is_client:
		if not ctx.common.connected:
			WyncJoin.service_wync_try_to_connect(ctx)  # reliable, commited
		else:
			WyncClock.wync_client_ask_for_clock(ctx)   # unreliable
			WyncDeltaSyncUtilsInternal.wync_system_client_send_delta_prop_acks(ctx) # unreliable
			WyncStateSend.wync_client_send_inputs(ctx) # unreliable
			WyncEventUtils.wync_send_event_data(ctx)   # reliable, commited

	else:
		WyncSpawn.wync_system_send_entities_to_despawn(ctx) # reliable, commited
		WyncSpawn.wync_system_send_entities_to_spawn(ctx)   # reliable, commited
		WyncInput.wync_system_sync_client_ownership(ctx)    # reliable, commited

		WyncThrottle.wync_system_fill_entity_sync_queue(ctx)
		WyncThrottle.wync_compute_entity_sync_order(ctx)
		WyncStateSend.wync_send_extracted_data(ctx) # both reliable/unreliable
	WyncStats.wync_system_calculate_data_per_tick(ctx)


static func _internal_wync_system_gather_packets_end(ctx: WyncCtx):
	# pending delta props fullsnapshots should be extracted by now
	WyncStateSend.wync_send_pending_rela_props_fullsnapshot(ctx)
	WyncStateSend._wync_queue_out_snapshots_for_delivery(ctx) # both reliable/unreliable



static func wync_feed_packet(ctx: WyncCtx, wync_pkt: WyncPacket, from_nete_peer_id: int) -> int:

	# debug statistics
	WyncDebug.log_packet_received(ctx, wync_pkt.packet_type_id)
	var is_client = ctx.common.is_client

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
				WyncDeltaSyncUtilsInternal.wync_handle_pkt_delta_prop_ack(ctx, wync_pkt.data, from_nete_peer_id)
		_:
			Log.errc(ctx, "wync packet_type_id(%s) not recognized skipping (%s)" % [wync_pkt.packet_type_id, wync_pkt.data])
			return -1

	return OK

# Setup functions
# ================================================================

static func server_setup(ctx: WyncCtx) -> int:
	# peer id 0 reserved for server
	ctx.common.is_client = false
	ctx.common.my_peer_id = 0
	ctx.common.peers.resize(1)
	ctx.common.peers[ctx.common.my_peer_id] = -1
	ctx.common.connected = true

	# setup event caching
	ctx.co_events.events_hash_to_id.init(ctx.common.max_amount_cache_events)
	ctx.co_events.to_peers_i_sent_events = []
	ctx.co_events.to_peers_i_sent_events.resize(ctx.common.max_peers)
	for i in range(ctx.common.max_peers):
		ctx.co_events.to_peers_i_sent_events[i] = FIFOMap.new()
		ctx.co_events.to_peers_i_sent_events[i].init(ctx.common.max_amount_cache_events)

	# setup relative synchronization
	ctx.co_throttling.peers_events_to_sync = []
	ctx.co_throttling.peers_events_to_sync.resize(ctx.common.max_peers)
	for i in range(ctx.common.max_peers):
		ctx.co_throttling.peers_events_to_sync[i] = {} as Dictionary

	# setup peer channels
	WyncEventUtils.setup_peer_global_events(ctx, WyncCtx.SERVER_PEER_ID)
	for i in range(1, ctx.common.max_peers):
		WyncEventUtils.setup_peer_global_events(ctx, i)

	# setup prob prop
	WyncStats.setup_entity_prob_for_entity_update_delay_ticks(ctx, WyncCtx.SERVER_PEER_ID)

	return 0


static func client_init(ctx: WyncCtx) -> int:
	ctx.common.is_client = true
	return OK


# ==================================================
# WRAPPER
# ==================================================


static func setup_context(ctx: WyncCtx):
	_internal_setup_context(ctx)
	WyncWrapper.wrapper_initialize(ctx)


## Note. Before running this, make sure to receive packets from the network

static func wync_server_tick_start(ctx: WyncCtx):

	WyncClock.wync_advance_ticks(ctx)

	WyncActions.module_events_consumed_advance_tick(ctx)

	WyncWrapper.wync_input_props_set_tick_value(ctx) # wrapper function

	WyncDeltaSyncUtilsInternal.delta_props_clear_current_delta_events(ctx)


static func wync_server_tick_end(ctx: WyncCtx):
	for peer_id: int in range(1, ctx.common.peers.size()):
		WyncClock.wync_system_stabilize_latency(ctx, ctx.common.peer_latency_info[peer_id])

	WyncXtrapInternal.wync_xtrap_server_filter_prop_ids(ctx)

	WyncStateSend.system_update_delta_base_state_tick(ctx)

	# NOTE: maybe a way to extract data but only events, since that is unskippable?
	# (shouldn't be throttled)
	# This function extracts regular props, plus _auxiliar delta event props_
	# We need a function to extract data exclusively of events... Like the equivalent
	# of the client's _input_bufferer_
	WyncWrapper.extract_data_to_tick(ctx, ctx.common.ticks) # wrapper function


static func wync_client_tick_end(ctx: WyncCtx):

	WyncXtrapInternal.wync_xtrap_client_filter_prop_ids(ctx)
	WyncClock.wync_advance_ticks(ctx)
	WyncClock.wync_system_stabilize_latency(ctx, ctx.common.peer_latency_info[WyncCtx.SERVER_PEER_ID])
	WyncClock.wync_update_prediction_ticks(ctx)
	
	WyncWrapper.wync_buffer_inputs(ctx) # wrapper function

	# CANNOT reset events BEFORE polling inputs, WHERE do we put this?
	
	WyncDeltaSyncUtilsInternal.delta_props_clear_current_delta_events(ctx)
	WyncDeltaSyncUtils.predicted_event_props_clear_events(ctx)

	WyncStateSet.wync_reset_props_to_latest_value(ctx)
	
	# NOTE: Maybe this one should be called AFTER consuming packets, and BEFORE xtrap
	WyncStats.wync_system_calculate_prob_prop_rate(ctx)

	WyncStats.wync_system_calculate_server_tick_rate(ctx)

	WyncStateStore.wync_service_cleanup_dummy_props(ctx)

	WyncLerp.wync_lerp_precompute(ctx)


static func wync_system_gather_packets(ctx: WyncCtx):
	_internal_wync_system_gather_packets_start(ctx)
	if !ctx.common.is_client:
		WyncWrapper.extract_rela_prop_fullsnapshot_to_tick(ctx, ctx.common.ticks)
	_internal_wync_system_gather_packets_end(ctx)
