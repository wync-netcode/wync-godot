extends System
class_name SyNeteLoopbackConnectReq
const label: StringName = StringName("SyNeteLoopbackConnectReq")


## Clients tries to "connect" to the first server it finds

func _ready():
	components = [CoClient.label, CoIOPackets.label, CoPeerRegisteredFlag.label]
	super()
	

func on_process_entity(entity: Entity, _data, _delta: float):
	var co_client = entity.get_component(CoClient.label) as CoClient

	# NOTE: Could use a flag instead

	if co_client.state != CoClient.STATE.DISCONNECTED:
		return

	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets
	var io_peer = co_io.io_peer
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback", Log.TAG_NETE_CONNECT)
		return
	
	# try to find a server

	var server_peer_id = 0
	if co_loopback.ctx.peers.size() == 0:
		Log.err("Couldn't find registered server peer in CoTransportLoopback", Log.TAG_NETE_CONNECT)
		return
	
	# "connect" to server
	
	var packet_data = NetePktJoinReq.new()
	var user_packet = UserNetPacket.new()
	user_packet.packet_type_id = GameInfo.NETE_PKT_ANY
	user_packet.data = packet_data
	Loopback.queue_packet(io_peer, server_peer_id, user_packet)
	
	# check for response packets

	for k in range(io_peer.in_packets.size()-1, -1, -1):
		var pkt = io_peer.in_packets[k] as Loopback.Packet
		var user_pkt = pkt.data as UserNetPacket
		var data = user_pkt.data as NetePktJoinRes
		if not data:
			continue
			
		# consume
		io_peer.in_packets.remove_at(k)
		
		if data.approved:
			co_client.state = CoClient.STATE.CONNECTED
		
		# save server address on client

		co_client.state = CoClient.STATE.CONNECTED
		co_client.identifier = data.identifier
		co_client.server_peer = pkt.from_peer

		# fill in wync nete_peer_ids
		# wync setup should be done once we've stablished connection
		
		var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
		var wync_ctx = single_wync.ctx as WyncCtx
		WyncUtils.wync_set_my_nete_peer_id(wync_ctx, io_peer.peer_id)
		WyncUtils.wync_set_server_nete_peer_id(wync_ctx, co_client.server_peer)

		Log.out("client_peer_id %s connected to server_peer_id %s" % [io_peer.peer_id, co_client.server_peer], Log.TAG_NETE_CONNECT)
