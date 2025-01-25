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
	
	var event_amount = wync_ctx.events_to_sync_this_tick.keys().size()
	if event_amount <= 0:
		return
	Log.out(self, "Event count to sync %s" % event_amount)
	
	var data = WyncPktEventData.new()
	data.events.resize(event_amount)
	
	var keys = wync_ctx.events_to_sync_this_tick.keys()
	for i in range(event_amount):
		var event_id = keys[i]
		Log.out(self, "event_id %s" % event_id)
		
		# get event
		
		if not wync_ctx.events.has(event_id):
			Log.err(self, "couldn't find event_id %s" % event_id)
			continue
		
		var wync_event = wync_ctx.events[event_id] as WyncEvent
		
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
		
		data.events[i] = event_data
		Log.out(self, "%s" % HashUtils.object_to_dictionary(event_data))
		
	# queue

	var pkt = NetPacket.new()
	pkt.to_peer = co_client.server_peer
	pkt.data = data
	co_io_packets.out_packets.append(pkt)
	Log.out(self, "sent")
