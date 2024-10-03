extends System
class_name SyTransportLoopbackConnection

## Clients tries to "connect" to the first server it finds

func _ready():
	components = "%s,%s" % [CoClient.label, CoIOPackets.label]
	super()
	

func on_process_entity(entity: Entity, _delta: float):
	var co_client = entity.get_component(CoClient.label) as CoClient

	# NOTE: Could use a flag instead

	if co_client.state != CoClient.STATE.DISCONNECTED:
		return

	var co_client_io = entity.get_component(CoIOPackets.label) as CoIOPackets
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return
	
	# try to find a server

	var co_server: CoServer = null
	var co_server_io: CoIOPackets = null

	for peer: LoopbackPeer in co_loopback.peers:
		if peer:
			var peer_entity = ECSUtils.get_entity_from_component(peer.peer_packet_buffer)
			if peer_entity:
				co_server = peer_entity.get_component(CoServer.label) as CoServer
				if co_server:
					co_server_io = peer.peer_packet_buffer
					break

	if not co_server_io:
		print("E: Couldn't find registered server peer in CoTransportLoopback")
		return

	# "connect" to server

	# register client on server

	var server_peer = CoServer.ServerPeer.new()
	server_peer.identifier = co_client_io.peer_id
	server_peer.peer_id = co_client_io.peer_id

	co_server.peers.append(server_peer)
	co_server.peer_count += 1
	
	# register server on client

	co_client.state = CoClient.STATE.CONNECTED
	co_client.identifier = server_peer.identifier
	co_client.server_peer = co_server_io.peer_id

	print("D: Client connected %s:%s to %s" % [entity, entity.name, co_server])
