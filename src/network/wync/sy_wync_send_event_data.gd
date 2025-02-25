extends System
class_name SyWyncSendEventData
const label: StringName = StringName("SyWyncSendEventData")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	if not ctx.connected:
		Log.err("Not connected", Log.TAG_EVENT_DATA)
		return

	# get co_io_packets

	var co_io_packets = null
	if WyncUtils.is_client(ctx):
		var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
		if not en_client:
			Log.err("Couldn't find singleton EnSingleClient", Log.TAG_EVENT_DATA)
			return
		co_io_packets = en_client.get_component(CoIOPackets.label) as CoIOPackets
	else:
		var en_server = ECS.get_singleton_entity(self, "EnSingleServer")
		if not en_server:
			Log.err("Couldn't find singleton EnSingleServer", Log.TAG_EVENT_DATA)
			return
		co_io_packets = en_server.get_component(CoIOPackets.label) as CoIOPackets

	if co_io_packets == null:
		Log.err("Couldn't find CoIOPackets", Log.TAG_EVENT_DATA)
		return

	# send events
	
	if WyncUtils.is_client(ctx):
		var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
		var co_client = en_client.get_component(CoClient.label) as CoClient
		if co_client.server_peer < 0:
			Log.err("No server peer", Log.TAG_EVENT_DATA)
			return
		send_events_to_peer(ctx, WyncCtx.SERVER_PEER_ID)
	else: # server
		for wync_peer_id in range(1, ctx.peers.size()):
			send_events_to_peer(ctx, wync_peer_id)


static func send_events_to_peer (ctx: WyncCtx, wync_peer_id: int):
	
	var event_keys = ctx.peers_events_to_sync[wync_peer_id].keys()
	var event_amount = event_keys.size()
	if event_amount <= 0:
		return
	#Log.out(self, "Event count to sync %s" % event_amount)
	
	var data = WyncPktEventData.new()
	
	for i in range(event_amount):
		var event_id = event_keys[i]
		#Log.out(self, "event_id %s" % event_id)
		
		# get event data
		
		if not ctx.events.has(event_id):
			Log.err("couldn't find event_id %s" % event_id, Log.TAG_EVENT_DATA)
			continue
		
		var wync_event = (ctx.events[event_id] as WyncEvent).data
		
		# check if server already has it
		var event_hash = HashUtils.hash_any(wync_event)
		# NOTE: is_serve_cached could be skipped? all events should be cached on our side...
		var is_event_cached = ctx.events_hash_to_id.has_item_hash(event_hash)
		if (is_event_cached):
			var cached_event_id = ctx.events_hash_to_id.get_item_by_hash(event_hash)
			if (cached_event_id != null):
				var server_has_it = ctx.to_peers_i_sent_events[wync_peer_id].has_item_hash(cached_event_id)
				if (server_has_it):
					continue
		
		# server doesn't have it
		ctx.to_peers_i_sent_events[wync_peer_id].push_head_hash_and_item(event_id, true)
		
		# package it
		
		var event_data = WyncPktEventData.EventData.new()
		event_data.event_id = event_id
		event_data.event_type_id = wync_event.event_type_id
		event_data.arg_count = wync_event.arg_count
		event_data.arg_data_type = wync_event.arg_data_type.duplicate(true)
		event_data.arg_data.resize(event_data.arg_count)
		
		for j in range(wync_event.arg_count):
			event_data.arg_data[j] = WyncUtils.duplicate_any(wync_event.arg_data[j])
			#Log.out(node_ctx, "%s" % [wync_event.arg_data[j]])
			#Log.out(node_ctx, "%s" % [event_data.arg_data[j]])
		
		data.events.append(event_data)
		
		#if WyncUtils.is_client(ctx):
			#Log.out("sending this event %s" % HashUtils.object_to_dictionary(event_data), Log.TAG_DEBUG3)
		
		if event_id == 105:
			print()
			print()
	
	if (data.events.size() == 0):
		return
	
	# queue

	var packet_dup = WyncUtils.duplicate_any(data)
	var result = WyncFlow.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_EVENT_DATA, packet_dup)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		ctx.out_packets.append(packet_out)

	Log.out("sent", Log.TAG_EVENT_DATA)
