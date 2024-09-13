extends System
class_name SyTransportLoopbackPeerRegister


func _ready():
	components = "%s" % [CoIOPackets.label]
	super()
	

func on_process(entities, _delta: float):
	var single_transport = ECS.get_singleton(self, "EnSingleTransportLoopback")
	if not single_transport:
		print("E: Couldn't find singleton EnSingleTransportLoopback")
		return
	var co_loopback = single_transport.get_component(CoTransportLoopback.label) as CoTransportLoopback


	# NOTE: Better to use a one off component tag
	if co_loopback.peers.size():
		return


	for i in range(entities.size()):
		var entity: Entity = entities[i]
		var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets
		co_io_packets.peer_id = i

		var loopback_peer = LoopbackPeer.new()
		loopback_peer.peer_packet_buffer = co_io_packets
		co_loopback.peers.append(loopback_peer)
