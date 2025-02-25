extends System
class_name SyUserWyncQueuePackets
const label: StringName = StringName("SyUserWyncQueuePackets")

## Send through the network packets from Wync


func on_process(_entities, _data, _delta: float):
	var co_io = null # : CoIOPackets*
	
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if single_client:
		var co_client = single_client.get_component(CoClient.label) as CoClient
		if co_client.state != CoClient.STATE.CONNECTED:
			return
		co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
		if single_server:
			co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		Log.err("Couldn't find co_io_packets", Log.TAG_WYNC_CONNECT)

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# queue _out packets_ for delivery

	for pkt: WyncPacketOut in wync_ctx.out_packets:
		
		# queue
		
		var packet = NetPacket.new()
		packet.packet_type_id = GameInfo.NETE_PKT_WYNC_PKT
		packet.to_peer = pkt.to_nete_peer_id

		# send contained WyncPacket
		# no need to copy I guess
		packet.data = pkt.data 

		co_io.out_packets.append(packet)

	# clear 
	wync_ctx.out_packets.clear()
