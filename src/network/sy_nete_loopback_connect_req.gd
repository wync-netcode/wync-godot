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
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback", Log.TAG_NETE_CONNECT)
		return
	
	# try to find a server

	var server_peer_id = -1

	for i in range(co_loopback.peers.size()):
		var peer: LoopbackPeer = co_loopback.peers[i]
		if peer:
			var peer_entity = ECSUtils.get_entity_from_component(peer.peer_packet_buffer)
			if peer_entity:
				if peer_entity.has_component(CoServer.label):
					server_peer_id = i

	if server_peer_id < 0:
		Log.err("Couldn't find registered server peer in CoTransportLoopback", Log.TAG_NETE_CONNECT)
		return
	
	# "connect" to server
	
	var packet_data = NetePktJoinReq.new()
	var packet = NetPacket.new()
	packet.to_peer = server_peer_id
	packet.data = packet_data
	co_io.out_packets.append(packet)
	
	# check for response packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as NetePktJoinRes
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
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
		WyncUtils.wync_set_my_nete_peer_id(wync_ctx, co_io.peer_id)
		WyncUtils.wync_set_server_nete_peer_id(wync_ctx, co_client.server_peer)

		Log.out("client_peer_id %s connected to server_peer_id %s" % [co_io.peer_id, co_client.server_peer], Log.TAG_NETE_CONNECT)
