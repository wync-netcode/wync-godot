extends System
class_name SyNeteLoopbackConnectRes
const label: StringName = StringName("SyNeteLoopbackConnectRes")

## Clients tries to "connect" to the first server it finds

func _ready():
	components = [CoServer.label, CoIOPackets.label, CoPeerRegisteredFlag.label]
	super()
	

func on_process_entity(entity: Entity, _data, _delta: float):
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback")
		return
	var co_server = entity.get_component(CoServer.label) as CoServer
	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets
	var io_peer = co_io.io_peer
	
	# save tick data from packets

	for k in range(io_peer.in_packets.size()-1, -1, -1):
		var pkt = io_peer.in_packets[k] as Loopback.Packet
		var user_pkt = pkt.data as UserNetPacket
		var data = user_pkt.data as NetePktJoinReq
		if not data:
			continue
			
		# consume
		io_peer.in_packets.remove_at(k)
	
		# check if not already registered
		var client_peer_id = pkt.from_peer
		var already_registered = false
		
		for peer: CoServer.ServerPeer in co_server.peers:
			if peer.peer_id == client_peer_id:
				already_registered = true
		
		if already_registered:
			Log.out("Client %s already registered" % client_peer_id, Log.TAG_NETE_CONNECT)
			continue

		# register client on server

		var server_peer = CoServer.ServerPeer.new()
		server_peer.identifier = client_peer_id
		server_peer.peer_id = client_peer_id

		co_server.peers.append(server_peer)
		co_server.peer_count += 1
		
		# send confirmation
		
		var packet_data = NetePktJoinRes.new()
		packet_data.approved = true
		packet_data.identifier = server_peer.identifier

		var user_packet = UserNetPacket.new()
		user_packet.packet_type_id = GameInfo.NETE_PKT_ANY
		user_packet.data = packet_data

		Loopback.queue_reliable_packet(co_loopback.ctx, io_peer, server_peer.peer_id, user_packet)
