extends System
class_name SyUserWyncConsumePackets
const label: StringName = StringName("SyUserWyncConsumePackets")

## Grab packets from the network to feed Wync


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
			var co_server = single_server.get_component(CoServer.label) as CoServer
			co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		Log.err("Couldn't find co_io_packets", Log.TAG_WYNC_CONNECT)

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# check for packets

	for pkt: NetPacket in wync_ctx.out_packets:
		
		# TODO: use a different packet struct unique to Wync
		# queue
		
		var packet = NetPacket.new()
		packet.to_peer = pkt.to_peer
		packet.data = pkt.data
		co_io.out_packets.append(packet)

	wync_ctx.out_packets.clear()
