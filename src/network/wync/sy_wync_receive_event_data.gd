extends System
class_name SyWyncReceiveEventData
const label: StringName = StringName("SyWyncReceiveEventData")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func on_process(_entities, _data, _delta: float):

	var en_peer = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_peer:
		en_peer = ECS.get_singleton_entity(self, "EnSingleServer")
	if not en_peer:
		Log.err(self, "Couldn't find singleton EnSingleClient or EnSingleServer")
		return
	var co_io = en_peer.get_component(CoIOPackets.label) as CoIOPackets

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		Log.err(self, "Not connected")
		return

	# save event data from packets
	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktEventData
		if not data:
			continue
		
		# consume
		Log.out(self, "Consume WyncPktEventData")
		co_io.in_packets.remove_at(k)

		for event: WyncPktEventData.EventData in data.events:
			
			var wync_event = WyncEvent.new()
			wync_event.event_type_id = event.event_type_id
			wync_event.arg_count = event.arg_count
			wync_event.arg_data_type = event.arg_data_type.duplicate(true)
			wync_event.arg_data = event.arg_data # std::move(std::unique_pointer)
			wync_ctx.events[event.event_id] = wync_event
		
			# NOTE: what if we already have this event data? Maybe it's better to receive it anyway?
