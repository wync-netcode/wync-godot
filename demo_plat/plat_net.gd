class_name PlatNet


static func initialize_net_state(gs: Plat.GameState, is_client: bool):
	gs.net = Plat.NetState.new()
	gs.net.io_peer = Loopback.IOPeer.new()
	gs.net.is_client = is_client

	if is_client:
		gs.net.client = Plat.Client.new()
		gs.net.client.identifier = -1
		gs.net.client.server_peer = -1
		gs.net.client.state = Plat.Client.STATE.DISCONNECTED

	else:
		gs.net.server = Plat.Server.new()
		gs.net.server.peer_count = 0
		gs.net.server.peers = []


static func register_peer_myself(gs: Plat.GameState):
	Loopback.register_io_peer(PlatGlobals.loopback_ctx, gs.net.io_peer)


static func client_send_connection_request(gs: Plat.GameState):
	var packet_data = NetePktJoinReq.new()
	var user_packet = UserNetPacket.new()
	user_packet.packet_type_id = GameInfo.NETE_PKT_ANY
	user_packet.data = packet_data
	# assuming server is peer 0
	Loopback.queue_reliable_packet(PlatGlobals.loopback_ctx, gs.net.io_peer, 0, user_packet)


static func client_handle_connection_request_response(gs: Plat.GameState, data: NetePktJoinRes, from_peer: int):
	if not data.approved:
		return

	var client = gs.net.client
	var io_peer = gs.net.io_peer
	client.state = Plat.Client.STATE.CONNECTED
	client.identifier = data.identifier
	client.server_peer = from_peer

	# fill in wync nete_peer_ids
	# wync setup should be done once we've stablished connection
	
	#WyncUtils.wync_set_my_nete_peer_id(wync_ctx, io_peer.peer_id)
	#WyncUtils.wync_set_server_nete_peer_id(wync_ctx, co_client.server_peer)
	Log.out("client_peer_id %s connected to server_peer_id %s" % [io_peer.peer_id, client.server_peer], Log.TAG_NETE_CONNECT)


static func server_handle_connection_request(gs: Plat.GameState, data: NetePktJoinReq, from_peer: int):
	var server = gs.net.server
	var client_peer_id = from_peer
	var already_registered = false

	# check if not already registered
	
	for peer: Plat.Server.Peer in server.peers:
		if peer.peer_id == client_peer_id:
			already_registered = true
	
	if already_registered:
		Log.out("Client %s already registered" % client_peer_id, Log.TAG_NETE_CONNECT)
		return

	# register client on server

	var server_peer = Plat.Server.Peer.new()
	server_peer.identifier = client_peer_id
	server_peer.peer_id = client_peer_id

	server.peers.append(server_peer)
	server.peer_count += 1
	
	# send confirmation
	
	var packet_data = NetePktJoinRes.new()
	packet_data.approved = true
	packet_data.identifier = server_peer.identifier

	var user_packet = UserNetPacket.new()
	user_packet.packet_type_id = GameInfo.NETE_PKT_ANY
	user_packet.data = packet_data

	Loopback.queue_reliable_packet(PlatGlobals.loopback_ctx, gs.net.io_peer, server_peer.peer_id, user_packet)


static func consume_loopback_packets(gs: Plat.GameState):
	var is_client = gs.net.is_client
	var is_server = not gs.net.is_client
	var io_peer = gs.net.io_peer

	for k in range(io_peer.in_packets.size()-1, -1, -1):
		var pkt = io_peer.in_packets[k] as Loopback.Packet
		var user_pkt = pkt.data as UserNetPacket
		var data = user_pkt.data

		if data is NetePktJoinReq:
			if is_server: server_handle_connection_request(gs, data, pkt.from_peer)
		elif data is NetePktJoinRes:
			if is_client: client_handle_connection_request_response(gs, data, pkt.from_peer)
			
	io_peer.in_packets.clear()
