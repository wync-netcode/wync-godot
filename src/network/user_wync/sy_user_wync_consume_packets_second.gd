extends System
class_name SyUserWyncConsumePacketsSecond
const label: StringName = StringName("SyUserWyncConsumePacketsSecond")

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
			co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	if co_io == null:
		Log.err("Couldn't find co_io_packets", Log.TAG_WYNC_CONNECT)
	var io_peer = co_io.io_peer

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# TODO

	for k in range(io_peer.in_packets.size()-1, -1, -1):
		var loo_pkt = io_peer.in_packets[k] as Loopback.Packet
		var pkt = loo_pkt.data as UserNetPacket

		# check for magic number
		if pkt.packet_type_id != GameInfo.NETE_PKT_WYNC_PKT:
			continue

		# TODO: actual real check for packet integrity

		if pkt.data is not WyncPacket:
			Log.err("Magic number detect but Packet is not WyncPacket (%s)" % [WyncPacket])
			continue
		var data = pkt.data as WyncPacket
		
		if not data.packet_type_id in [WyncPacket.WYNC_PKT_JOIN_RES, WyncPacket.WYNC_PKT_RES_CLIENT_INFO]:
			continue

		WyncFlow.wync_feed_packet(wync_ctx, data, loo_pkt.from_peer)

		# consume
		io_peer.in_packets.remove_at(k)
