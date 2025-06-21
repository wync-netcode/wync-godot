class_name WyncStateSend
	
	
## Ideal loop
## * Sync all VIP props
## * Sync all other props
## This service writes state (ctx.client_has_relative_prop_has_last_tick)
static func wync_send_extracted_data(ctx: WyncCtx):

	var data_used = 0

	# TODO: Allocate a LIST OF PACKETS, because we're gonna be generating all kinds of packets:
	# * On C use a custom byte buffer, it's only use locally so no need to make it complex
	# 1. WyncPktSnap (each varies in size...)
	# 2. WyncPktInputs (are all the same size, but their size is (User) configurable)
	# 3. WyncPktEventData (varies in size)

	# byte buffer
	# Array < client_id: int, List < WyncPacket > >
	# Array < client_id: int, Array < idx: int, WyncPacket > >
	# Array[Array[WyncPacket]]
	var clients_packet_buffer_reliable: Array[Array] = []
	var clients_packet_buffer_unreliable: Array[Array] = []
	clients_packet_buffer_reliable.resize(ctx.peers.size())
	clients_packet_buffer_unreliable.resize(ctx.peers.size())
	for client_id: int in range(1, ctx.peers.size()):
		clients_packet_buffer_reliable[client_id] = [] as Array[WyncPacket]
		clients_packet_buffer_unreliable[client_id] = [] as Array[WyncPacket]

	# build packet

	for pair: WyncCtx.PeerEntityPair in ctx.queue_entity_pairs_to_sync:
		var client_id = pair.peer_id
		var entity_id = pair.entity_id

		var reliable_buffer := clients_packet_buffer_reliable[client_id] as Array[WyncPacket]
		var unreliable_buffer := clients_packet_buffer_unreliable[client_id] as Array[WyncPacket]
		var reliable_snap := WyncPktSnap.new()
		reliable_snap.tick = ctx.co_ticks.ticks
		var unreliable_snap := WyncPktSnap.new()
		unreliable_snap.tick = ctx.co_ticks.ticks

		# TODO (1): Notify wync this entity was successfully updated
		# wync_mark_entity_as_updated
		# wync_remove_entity_from_update_queue(ctx, entity_id, client_id)
		# TODO (2): Notify wync user has last tick
		# client_prop_last_tick[prop_id] = co_ticks.tick

		WyncThrottle._wync_remove_entity_from_sync_queue(ctx, client_id, entity_id)

		# fill all the data for the props, then see if it fits

		var prop_ids_array = ctx.entity_has_props[entity_id] as Array
		assert(prop_ids_array.size())

		for prop_id in prop_ids_array:
			var prop := WyncTrack.get_prop(ctx, prop_id)
			if prop == null:
				continue

			# ignore inputs
			if prop.prop_type == WyncEntityProp.PROP_TYPE.INPUT:
				continue

			# sync events, including their data
			# (auxiliar props included)
			elif prop.prop_type == WyncEntityProp.PROP_TYPE.EVENT:
				
				# don't send if client owns this prop
				if ctx.client_owns_prop[client_id].has(prop_id):
					continue

				# this includes _regular_ and _auxiliar_ props
				var pkt_input := wync_prop_event_send_event_ids_to_peer (ctx, prop, prop_id)

				# commit
				var packet = WyncPacket.new()
				packet.packet_type_id = WyncPacket.WYNC_PKT_INPUTS
				packet.data = pkt_input
				data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_INPUTS)
				unreliable_buffer.append(packet)

				# compile event ids
				var event_ids := [] as Array[int] # TODO: Use a C friendly expression
				for input: WyncPktInputs.NetTickDataDecorator in pkt_input.inputs:
					for event_id in (input.data):
						event_ids.append(event_id)
						#if event_id is Array:
							#assert(false)

				# get event data
				var pkt_event_data = wync_get_event_data_packet(ctx, client_id, event_ids)
				if pkt_event_data.events.size() > 0:
					# commit
					var packet_events = WyncPacket.new()
					packet_events.packet_type_id = WyncPacket.WYNC_PKT_EVENT_DATA
					packet_events.data = pkt_event_data
					reliable_buffer.append(packet_events)
					data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_EVENT_DATA)

				#Log.outc(ctx, "tag1 | this is my pkt_input %s" % [JsonClassConverter.class_to_json_string(pkt_input)])
				#Log.outc(ctx, "tag1 | this is my pkt_event_data %s" % [JsonClassConverter.class_to_json_string(pkt_event_data)])

			# relative syncable receives special treatment?
			elif prop.relative_syncable:
				if prop.timewarpable: # NOT supported: relative_syncable + timewarpable
					continue
				var snap_prop := _wync_sync_relative_prop_base_only(ctx, prop, prop_id, client_id)
				if snap_prop != null:
					reliable_snap.snaps.append(snap_prop)


			## regular declarative prop
			else:

				var snap_prop := _wync_sync_regular_prop(ctx, prop, prop_id, ctx.co_ticks.ticks)
				if snap_prop != null:
					unreliable_snap.snaps.append(snap_prop)

		# commit snap packet

		if unreliable_snap.snaps.size() > 0:
			var packet = WyncPacket.new()
			packet.packet_type_id = WyncPacket.WYNC_PKT_PROP_SNAP
			packet.data = unreliable_snap
			unreliable_buffer.append(packet)
			data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_PROP_SNAP)

		if reliable_snap.snaps.size() > 0:
			var packet = WyncPacket.new()
			packet.packet_type_id = WyncPacket.WYNC_PKT_PROP_SNAP
			packet.data = reliable_snap
			reliable_buffer.append(packet)
			data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_PROP_SNAP)

		# exceeded size, stop

		if (data_used >= ctx.out_packets_size_remaining_chars):
			break

	# queue _out packets_ for delivery

	for client_id: int in range(1, ctx.peers.size()):
		var reliable_buffer := clients_packet_buffer_reliable[client_id] as Array[WyncPacket]
		var unreliable_buffer := clients_packet_buffer_unreliable[client_id] as Array[WyncPacket]

		for packet: WyncPacket in unreliable_buffer:
			var packet_dup = WyncMisc.duplicate_any(packet.data)

			var result = WyncPacketUtil.wync_wrap_packet_out(ctx, client_id, packet.packet_type_id, packet_dup)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, true)
			else:
				Log.errc(ctx, "error wrapping packet")

		for packet: WyncPacket in reliable_buffer:
			var packet_dup = WyncMisc.duplicate_any(packet.data)

			var result = WyncPacketUtil.wync_wrap_packet_out(ctx, client_id, packet.packet_type_id, packet_dup)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)
			else:
				Log.errc(ctx, "error wrapping packet")


static func _wync_sync_regular_prop(_ctx: WyncCtx, prop: WyncEntityProp, prop_id: int, tick: int) -> WyncPktSnap.SnapProp:

	# copy cached data
	
	var state = WyncEntityProp.saved_state_get(prop, tick)
	if state == null:
		return null

	# build packet

	var prop_snap := WyncPktSnap.SnapProp.new()
	prop_snap.prop_id = prop_id
	prop_snap.state = WyncMisc.duplicate_any(state)

	return prop_snap

			
## Sends to clients the latest _base state_ of a delta prop
## Assumes recepeit, send as reliable
## TODO: Move to wrapper

static func _wync_sync_relative_prop_base_only(
	ctx: WyncCtx,
	prop: WyncEntityProp,
	prop_id: int,
	client_id: int
	) -> WyncPktSnap.SnapProp:

	# FIXME: Optimization ideas:
	# 1. (probably not) Adelantar ticks en los que no pasó nada. Es decir automaticamente
	# aumentar el número del tick de un peer 'last_tick_confirmed'. Esto trae problemas por el
	# determinismo, pues no se enviaría ticks intermedios, es decir, el cliente debe saber.
	# send fullsnapshot if client doesn't have history, or if it's too old
	# 2. Podriamos evitar enviar actualizaciones si se detecta que el cliente está desconectado
	# temporalmente (1-3 mins); Wync actualmente no sabe cuando un peer está sufriendo desconexión
	# temporal; se podría crear un mecanismo para esto o usar _last_tick_.

	var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
	if not client_relative_props.has(prop_id):
		client_relative_props[prop_id] = -1

	var peer_latency_info = ctx.peer_latency_info[client_id] as WyncCtx.PeerLatencyInfo
	var latency_ticks: int = (peer_latency_info.latency_stable_ms) / (1000.0 / ctx.physic_ticks_per_second)

	if (ctx.delta_base_state_tick - client_relative_props[prop_id] < (latency_ticks * 4)):
		return null

	Log.outc(ctx, "debugack | client_has (%s) (%s) , base_tick (%s)" % [
		client_relative_props[prop_id], client_relative_props[prop_id] + latency_ticks, ctx.delta_base_state_tick])
	
	# ===========================================================
	# Save state history per tick
	
	var getter = ctx.wrapper.prop_getter[prop_id]
	var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
	var state = getter.call(user_ctx) # getter already gives a copy
	var prop_snap = WyncPktSnap.SnapProp.new()
	prop_snap.prop_id = prop_id
	prop_snap.state = state

	client_relative_props[prop_id] = ctx.co_ticks.ticks
	Log.outc(ctx, "debugdelta | client_has (%s) , base_tick (%s)" % [client_relative_props[prop_id], ctx.delta_base_state_tick])

	return prop_snap


# TODO: Make a separate version only for _event_ids_ different from _inputs any_
# TODO: Make a separate version only for _delta event_ids_
static func wync_prop_event_send_event_ids_to_peer(ctx: WyncCtx, prop: WyncEntityProp, prop_id: int) -> WyncPktInputs:

	# prepare packet

	var pkt_inputs = WyncPktInputs.new()

	for tick in range(ctx.co_ticks.ticks - WyncCtx.INPUT_AMOUNT_TO_SEND, ctx.co_ticks.ticks +1):

		var input = WyncEntityProp.saved_state_get(prop, tick)
		if input == null:
			Log.errc(ctx, "we don't have an input for this tick %s prop %s(id %s)" % [tick, prop.name_id, prop_id], Log.TAG_DELTA_EVENT)
			continue
		
		var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
		tick_input_wrap.tick = tick
		
		var copy = WyncMisc.duplicate_any(input)
		if copy == null:
			Log.errc(ctx, "WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_DELTA_EVENT)
			continue
		tick_input_wrap.data = copy if copy != null else input
			
		pkt_inputs.inputs.append(tick_input_wrap)

	pkt_inputs.amount = pkt_inputs.inputs.size()
	pkt_inputs.prop_id = prop_id

	return pkt_inputs


## This system writes state
static func wync_get_event_data_packet (ctx: WyncCtx, peer_id: int, event_ids: Array[int]) -> WyncPktEventData:
	
	var packet = WyncPktEventData.new()
		
	# get event data
	
	for event_id: int in event_ids:
		if not ctx.events.has(event_id):
			Log.err("couldn't find event_id %s" % event_id, Log.TAG_EVENT_DATA)
			continue
		
		var wync_event := ctx.events[event_id]
		var wync_event_data = wync_event.data
		
		# check if peer already has it
		# NOTE: is_serve_cached could be skipped? all events should be cached on our side...
		var is_event_cached = ctx.events_hash_to_id.has_item_hash(wync_event.data_hash)
		if (is_event_cached):
			var cached_event_id = ctx.events_hash_to_id.get_item_by_hash(wync_event.data_hash)
			if (cached_event_id != null):
				var peer_has_it = ctx.to_peers_i_sent_events[peer_id].has_item_hash(cached_event_id)
				if (peer_has_it):
					continue
		
		# package it
		
		var event_data = WyncPktEventData.EventData.new()
		event_data.event_id = event_id
		event_data.event_type_id = wync_event_data.event_type_id
		event_data.event_data = WyncMisc.duplicate_any(wync_event_data.event_data)
		packet.events.append(event_data)

		# commit
		# since peer doesn't have it, then mark it as sent
		ctx.to_peers_i_sent_events[peer_id].push_head_hash_and_item(event_id, true)

	return packet


## This function must be ran each frame

static func system_update_delta_base_state_tick(ctx: WyncCtx) -> void:

	# move base_state_tick forward

	var new_base_tick = ctx.co_ticks.ticks - ctx.max_prop_relative_sync_history_ticks +1
	if not (ctx.delta_base_state_tick < new_base_tick):
		return
	ctx.delta_base_state_tick = new_base_tick


## * Sends inputs/events in chunks
## TODO: either throttle or commit to the packet
## This system writes state (ctx.peers_events_to_sync) but it's naturally redundant
## So think about it as if it didn't write state
static func wync_client_send_inputs (ctx: WyncCtx):

	assert(ctx.connected)

	var co_predict_data = ctx.co_predict_data
	var tick_pred = co_predict_data.target_tick
	
	# reset events_id to sync
	var event_set = ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID] as Dictionary
	event_set.clear()
	
	for prop_id in ctx.type_input_event__owned_prop_ids:
		var input_prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		# prepare packet
		# NOTE: Data size limit could be imposed at this level too

		var pkt_inputs = WyncPktInputs.new()

		for i in range(tick_pred - WyncCtx.INPUT_AMOUNT_TO_SEND, tick_pred +1):
			var input = WyncEntityProp.saved_state_get(input_prop, i)
			if input == null:
				# TODO: Implement input duplication on frame skip
				Log.outc(ctx, "prop(%s) don't have input for tick %s" % [prop_id, i])
				continue
			
			var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
			tick_input_wrap.tick = i
			
			var copy = WyncMisc.duplicate_any(input)
			if copy == null:
				Log.out("WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_INPUT_BUFFER)
			tick_input_wrap.data = copy if copy != null else input
				
			pkt_inputs.inputs.append(tick_input_wrap)
			
			# compile events ids
			if (input_prop.prop_type == WyncEntityProp.PROP_TYPE.EVENT &&
				input is Array):
				input = input as Array
				for event_id: int in input:
					event_set[event_id] = true

		pkt_inputs.amount = pkt_inputs.inputs.size()
		pkt_inputs.prop_id = prop_id
		#Log.out(self, "INPUT Sending prop %s" % [input_prop.name_id]) 
		#if input_prop.prop_type == WyncEntityProp.prop_type.EVENT:
			#Log.outc(ctx, "tic(%s) setted | sending prop (%s) (%s) " % [tick_pred, prop_id, pkt_inputs.inputs[0].data])

		# prepare peer packet and send (queue)

		var result = WyncPacketUtil.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_INPUTS, pkt_inputs)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			var err = WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)
			if err != OK: # Out of space
				break

	#Log.outc(ctx, "debugevents | TOTAL events to sync %s" % [event_set.keys()])
