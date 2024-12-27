extends System
class_name SyWyncConnectRes
const label: StringName = StringName("SyWyncConnectRes")

## Setup Wync client


func _ready():
	components = [
		CoSingleWyncContext.label
	]
	super()


func on_process(entities, _data, _delta: float):
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		Log.err(self, "No single_client")
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if wync_ctx.connected:
		return
	var co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinReq
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
		# send confirmation
		
		var packet_data = WyncPktJoinRes.new()
		packet_data.approved = true
		var packet = NetPacket.new()
		packet.to_peer = pkt.from_peer
		packet.data = packet_data
		co_io.out_packets.append(packet)
