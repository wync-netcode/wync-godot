extends System
class_name SyTransportLoopbackConnection

func _ready():
	components = "%s,%s" % [CoClient.label, CoIOPackets.label]
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var co_client = entity.get_component(CoClient.label) as CoClient
	var co_client_io = entity.get_component(CoIOPackets.label) as CoIOPackets

	# singletons

	var single_server = ECS.get_singleton(entity, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find server singleton EnSingleServer")
		return
	var co_server = single_server.get_component(CoServer.label) as CoServer
	var co_server_io = single_server.get_component(CoIOPackets.label) as CoIOPackets

	# connect client

	if co_client.state == CoClient.STATE.DISCONNECTED:

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

		print("Client connected %s:%s " % [entity, entity.name])
