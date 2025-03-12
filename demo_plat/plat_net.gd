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
