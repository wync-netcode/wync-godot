class_name WyncInit


# Intend:
# 1. Have all (most) allocations in one place
# 2. Remove initialization from class declarations

# Q: Isn't it better for each module to manage it's initialization?
# A: Do that, where it makes sense


static func init_ctx_common(ctx: WyncCtx):
	ctx.common.max_peers = 4
	ctx.common.physic_ticks_per_second = 60
	ctx.common.my_peer_id = -1
	ctx.common.my_nete_peer_id = -1
	ctx.common.max_amount_cache_events = 1024
	ctx.common.max_channels = 8
	ctx.common.max_prop_relative_sync_history_ticks = 20
	ctx.common.max_age_user_events_for_consumption = 120
	ctx.common.peer_latency_info.resize(ctx.common.max_peers)
	ctx.common.client_has_info.resize(ctx.common.max_peers)

	for peer_i in range(ctx.common.max_peers):
		var latency_info = WyncCtx.PeerLatencyInfo.new()
		latency_info.latency_buffer.resize(WyncCtx.LATENCY_BUFFER_SIZE)
		ctx.common.peer_latency_info[peer_i] = latency_info


static func init_ctx_state_tracking(ctx: WyncCtx):
	var max_peers = ctx.common.max_peers

	ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT = 8
	ctx.co_track.props.resize(ctx.MAX_PROPS)
	ctx.co_track.prop_id_cursor = 0
	ctx.co_track.active_prop_ids = []
	ctx.co_track.client_has_relative_prop_has_last_tick.resize(max_peers) # NOTE: index 0 not used
	for peer_i in range(max_peers):
		ctx.co_track.client_has_relative_prop_has_last_tick[peer_i] = {}


static func init_ctx_clientauth(ctx: WyncCtx):
	pass


static func init_ctx_events(ctx: WyncCtx):
	var max_peers = ctx.common.max_peers
	var max_channels = ctx.common.max_channels

	ctx.co_events.peer_has_channel_has_events.resize(max_peers)
	ctx.co_events.prop_id_by_peer_by_channel.resize(max_peers)

	for peer_i in range(max_peers):
		ctx.co_events.peer_has_channel_has_events[peer_i] = []
		ctx.co_events.peer_has_channel_has_events[peer_i].resize(max_channels)
		ctx.co_events.prop_id_by_peer_by_channel[peer_i] = []
		ctx.co_events.prop_id_by_peer_by_channel[peer_i].resize(max_channels)
		for channel_i in range(max_channels):
			ctx.co_events.peer_has_channel_has_events[peer_i][channel_i] = []
			ctx.co_events.prop_id_by_peer_by_channel[peer_i][channel_i] = -1


static func init_ctx_metrics(ctx: WyncCtx):
	ctx.co_metrics.debug_data_per_tick_sliding_window_size = 8
	ctx.co_metrics.low_priority_entity_update_rate_sliding_window_size = 8
	ctx.co_metrics.PROP_ID_PROB = -1

	ctx.co_metrics.debug_data_per_tick_sliding_window = \
		RingBuffer.new(ctx.co_metrics.debug_data_per_tick_sliding_window_size, 0)
	ctx.co_metrics.server_tick_rate_sliding_window = \
		RingBuffer.new(ctx.SERVER_TICK_RATE_SLIDING_WINDOW_SIZE, 0)
	ctx.co_metrics.low_priority_entity_update_rate_sliding_window = \
		RingBuffer.new(ctx.co_metrics.low_priority_entity_update_rate_sliding_window_size, 0)

	ctx.co_metrics.debug_packets_received.resize(WyncPacket.WYNC_PKT_AMOUNT)

	for i in range(WyncPacket.WYNC_PKT_AMOUNT):
		ctx.co_metrics.debug_packets_received[i] = [] as Array[int]
		ctx.co_metrics.debug_packets_received[i].resize(20) # amount of props, also 0 is reserved for 'total'


static func init_ctx_spawn(ctx: WyncCtx):
	ctx.co_spawn.out_queue_spawn_events = FIFORingAny.new(1024)


static func init_ctx_throttling(ctx: WyncCtx):
	var max_peers = ctx.common.max_peers

	ctx.co_throttling.queue_clients_entities_to_sync.resize(max_peers)
	ctx.co_throttling.queue_entity_pairs_to_sync.resize(100)

	ctx.co_throttling.clients_sees_entities.resize(max_peers)
	ctx.co_throttling.clients_sees_new_entities.resize(max_peers)
	ctx.co_throttling.clients_no_longer_sees_entities.resize(max_peers)
	ctx.co_throttling.entities_synced_last_time.resize(max_peers)

	ctx.co_throttling.clients_cached_unreliable_snapshots.resize(max_peers)
	ctx.co_throttling.clients_cached_reliable_snapshots.resize(max_peers)

	for peer_i in range(max_peers):

		#if peer_i != WyncCtx.SERVER_PEER_ID:
		ctx.co_throttling.queue_clients_entities_to_sync[peer_i] = FIFORing.new()
		ctx.co_throttling.queue_clients_entities_to_sync[peer_i].init(128) # TODO: Make this user defined
		ctx.co_throttling.clients_sees_entities[peer_i] = {}
		ctx.co_throttling.clients_sees_new_entities[peer_i] = {}
		ctx.co_throttling.clients_no_longer_sees_entities[peer_i] = {}
		ctx.co_throttling.entities_synced_last_time[peer_i] = {}

		ctx.co_throttling.clients_cached_reliable_snapshots[peer_i] = \
			[] as Array[WyncPktSnap.SnapProp]
		ctx.co_throttling.clients_cached_unreliable_snapshots[peer_i] = \
			[] as Array[WyncPktSnap.SnapProp]


static func init_ctx_ticks(ctx: WyncCtx):
	ctx.co_ticks.server_tick_offset_collection.resize(
		WyncCtx.SERVER_TICK_OFFSET_COLLECTION_SIZE)

	for i: int in range(WyncCtx.SERVER_TICK_OFFSET_COLLECTION_SIZE):
		var tuple = [0, 0]
		ctx.co_ticks.server_tick_offset_collection[i] = tuple


static func init_ctx_prediction_data(ctx: WyncCtx) -> void:
	ctx.co_pred.clock_offset_sliding_window_size = 16
	ctx.co_pred.clock_offset_sliding_window = RingBuffer.new(ctx.co_pred.clock_offset_sliding_window_size, 0)

	ctx.co_pred.first_tick_predicted = 1
	ctx.co_pred.last_tick_predicted = 0
	ctx.co_pred.tick_action_history_size = 32
	ctx.co_pred.tick_action_history = \
		RingBuffer.new(ctx.co_pred.tick_action_history_size, {})

	for i in range(ctx.co_pred.tick_action_history_size):
		ctx.co_pred.tick_action_history.insert_at(i, {} as Dictionary)


static func init_ctx_lerp(ctx: WyncCtx):
	ctx.co_lerp.lerp_ms = 50
	ctx.co_lerp.lerp_latency_ms = 0
	ctx.co_lerp.max_lerp_factor_symmetric = 1.0


static func init_ctx_dummy(ctx: WyncCtx):
	ctx.co_dummy.dummy_props = {}


static func init_ctx_filter_s(ctx: WyncCtx):
	pass


static func init_ctx_filter_c(ctx: WyncCtx):
	pass
