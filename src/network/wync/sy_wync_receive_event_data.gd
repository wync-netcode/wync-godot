extends System
class_name SyWyncReceiveEventData
const label: StringName = StringName("SyWyncReceiveEventData")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func on_process(_entities, _data, _delta: float, node_root: Node = null):
	
	var node_self = self if node_root == null else node_root
	var en_peer = ECS.get_singleton_entity(node_self, "EnSingleClient")
	if not en_peer:
		en_peer = ECS.get_singleton_entity(node_self, "EnSingleServer")
	if not en_peer:
		Log.err("Couldn't find singleton EnSingleClient or EnSingleServer", Log.TAG_EVENT_DATA)
		return
	var co_io = en_peer.get_component(CoIOPackets.label) as CoIOPackets

	var single_wync = ECS.get_singleton_component(node_self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		Log.err("Not connected", Log.TAG_EVENT_DATA)
		return

	# save event data from packets
	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktEventData
		if not data:
			continue

		WyncFlow.wync_handle_pkt_event_data(wync_ctx, data)
		
		# consume
		Log.out("events | Consume WyncPktEventData", Log.TAG_EVENT_DATA)
		co_io.in_packets.remove_at(k)
