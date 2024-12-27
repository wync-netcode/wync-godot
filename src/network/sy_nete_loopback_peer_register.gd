extends System
class_name SyNeteLoopbackPeerRegister
const label: StringName = StringName("SyNeteLoopbackPeerRegister")


## Registers this peer (server or client) to the Global Fake Network

func _ready():
	components = [CoIOPackets.label, -CoPeerRegisteredFlag.label]
	super()
	

func on_process_entity(entity, _data, _delta: float):
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	# register

	var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets
	co_io_packets.peer_id = co_loopback.peers.size()

	var loopback_peer = LoopbackPeer.new()
	loopback_peer.peer_packet_buffer = co_io_packets
	co_loopback.peers.append(loopback_peer)

	var flag = CoPeerRegisteredFlag.new()
	ECS.entity_add_component_node(entity, flag)
	print("D: Registered Peer %s:%s with id %s" % [entity, entity.name, co_io_packets.peer_id])
