extends System
class_name SyWyncSendEventData
const label: StringName = StringName("SyWyncSendEventData")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err(self, "Couldn't find singleton EnSingleClient")
		return
	var co_client = en_client.get_component(CoClient.label) as CoClient
	var co_io_packets = en_client.get_component(CoIOPackets.label) as CoIOPackets
	if co_client.server_peer < 0:
		Log.err(self, "No server peer")
		return
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		Log.err(self, "Not connected")
		return
	
	var event_keys = wync_ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID].keys()
	var event_amount = event_keys.size()
	if event_amount <= 0:
		return
	#Log.out(self, "Event count to sync %s" % event_amount)
	
	var data = WyncPktEventData.new()
	
	for i in range(event_amount):
		var event_id = event_keys[i]
		#Log.out(self, "event_id %s" % event_id)
		
		# get event data
		
		if not wync_ctx.events.has(event_id):
			Log.err(self, "couldn't find event_id %s" % event_id)
			continue
		
		var wync_event = (wync_ctx.events[event_id] as WyncEvent).data
		
		# check if server already has it
		var event_hash = HashUtils.hash_any(wync_event)
		# NOTE: is_serve_cached could be skipped? all events should be cached on our side...
		var is_event_cached = wync_ctx.events_hash_to_id.has_item_hash(event_hash)
		if (is_event_cached):
			var cached_event_id = wync_ctx.events_hash_to_id.get_item_by_hash(event_hash)
			if (cached_event_id != null):
				var server_has_it = wync_ctx.to_peers_i_sent_events[wync_ctx.SERVER_PEER_ID].has_item_hash(cached_event_id)
				if (server_has_it):
					continue
		
		# server doesn't have it
		wync_ctx.to_peers_i_sent_events[wync_ctx.SERVER_PEER_ID].push_head_hash_and_item(event_id, true)
		
		# package it
		
		var event_data = WyncPktEventData.EventData.new()
		event_data.event_id = event_id
		event_data.event_type_id = wync_event.event_type_id
		event_data.arg_count = wync_event.arg_count
		event_data.arg_data_type = wync_event.arg_data_type.duplicate(true)
		event_data.arg_data.resize(event_data.arg_count)
		
		for j in range(wync_event.arg_count):
			event_data.arg_data[j] = WyncUtils.duplicate_any(wync_event.arg_data[j])
			Log.out(self, "%s" % [wync_event.arg_data[j]])
			Log.out(self, "%s" % [event_data.arg_data[j]])
		
		data.events.append(event_data)
		Log.out(self, "%s" % HashUtils.object_to_dictionary(event_data))
	
	if (data.events.size() == 0):
		return
	
	# queue

	var pkt = NetPacket.new()
	pkt.to_peer = co_client.server_peer
	pkt.data = data
	co_io_packets.out_packets.append(pkt)
	Log.out(self, "sent")
