extends System
class_name SyTransportLoopbackConnection

func _ready():
	components = "%s,%s" % [CoClient.label, CoLoopbackPeers.label]
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var co_client = entity.get_component(CoClient.label) as CoClient
	var co_client_peers = entity.get_component(CoLoopbackPeers.label) as CoLoopbackPeers
	var co_client_io = entity.get_component(CoIOPackets.label) as CoIOPackets

	# singletons

	var single_server = ECS.get_singleton(entity, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find server singleton EnSingleServer")
		return
	var co_server = single_server.get_component(CoServer.label) as CoServer
	var co_server_peers = single_server.get_component(CoLoopbackPeers.label) as CoLoopbackPeers
	var co_server_io = single_server.get_component(CoIOPackets.label) as CoIOPackets

	# connect client

	if co_client.state == CoClient.STATE.DISCONNECTED:

		# register client on server

		var peer = LoopbackPeer.new()
		peer.peer_packet_buffer = co_client_io
		co_server_peers.peers.append(peer)

		var server_peer = CoServer.ServerPeer.new()
		server_peer.identifier = co_server.peer_count
		server_peer.peer_key = co_server.peer_count

		co_server.peers.append(server_peer)
		
		# register server on client

		co_client.state = CoClient.STATE.CONNECTED
		co_client.identifier = co_server.peer_count
		co_client.server_peer = 0

		peer = LoopbackPeer.new()
		peer.peer_packet_buffer = co_server_io
		co_client_peers.peers.clear()
		co_client_peers.peers.append(peer)

		co_server.peer_count += 1

		print("Client connected %s:%s " % [entity, entity.name])
