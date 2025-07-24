class_name WyncDeltaSyncUtilsInternal


static func prop_set_auxiliar(ctx: WyncCtx, prop_id: int, auxiliar_pair: int, undo_events: int) -> int: 
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncProp
	if (prop.prop_type != WyncProp.PROP_TYPE.EVENT):
		return 2
	prop.is_auxiliar_prop = true
	prop.auxiliar_delta_events_prop_id = auxiliar_pair

	# undo events are only for prediction and timewarp
	if undo_events:
		prop.confirmed_states_undo = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, [])
		prop.confirmed_states_undo_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
	return OK


static func auxiliar_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id in ctx.filtered_delta_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		prop.current_delta_events.clear()
		
		var aux_prop := WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		aux_prop.current_undo_delta_events.clear()


## returns int: Error
static func event_is_healthy (ctx: WyncCtx, event_id: int) -> int:
	# get event transform function
	# TODO: Make a new function get_event(event_id)
	
	if not ctx.events.has(event_id):
		Log.errc(ctx, "delta sync | couldn't find event (id %s)" % [event_id])
		return 1

	var event_data = ctx.events[event_id]
	if event_data is not WyncCtx.WyncEvent:
		Log.errc(ctx, "delta sync | event (id %s) found but invalid" % [event_id])
		return 2

	return OK


## High level functions related to logic cycles
static func wync_system_client_send_delta_prop_acks(ctx: WyncCtx):

	var prop_amount = 0
	var delta_prop_ids: Array[int] = []
	var last_tick_received: Array[int] = []
	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary

	for prop_id in ctx.type_state__delta_prop_ids:
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

	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_DELTA_PROP_ACK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)


static func wync_handle_pkt_delta_prop_ack(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktDeltaPropAck:
		return 1
	data = data as WyncPktDeltaPropAck

	# TODO: check client is healthy

	var client_id = WyncJoin.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.errc(ctx, "client %s is not registered" % client_id)
		return 2

	var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary

	# update latest _delta prop_ acked tick

	for i: int in range(data.prop_amount):
		var prop_id: int = data.delta_prop_ids[i]
		var last_tick: int = data.last_tick_received[i]

		if last_tick > ctx.co_ticks.ticks: # cannot be in the future
			Log.errc(ctx, "W: last_tick is in the future prop(%s) tick(%s)" % [prop_id, last_tick])
			continue

		var prop := WyncTrack.get_prop(ctx, prop_id)
		if not prop:
			Log.outc(ctx, "W: Couldn't find this prop %s" % [prop_id])
			continue

		if not client_relative_props.has(prop_id):
			Log.outc(ctx, "W: Client might no be 'seeing' this prop %s" % [prop_id])
			continue

		client_relative_props[prop_id] = max(last_tick, client_relative_props[prop_id])
		#Log.outc(ctx, "debugack | prop(%s) tick(%s)" % [prop_id, last_tick])

	return OK


static func entity_has_delta_prop(ctx: WyncCtx, entity_id: int) -> bool:
	if not ctx.entity_has_props.has(entity_id):
		return false
	for prop_id in ctx.entity_has_props[entity_id]:
		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.relative_syncable:
			return true
	return false
