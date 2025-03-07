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
	var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets

	# register

	Loopback.register_io_peer(co_loopback.ctx, co_io_packets.io_peer)

	var flag = CoPeerRegisteredFlag.new()
	ECS.entity_add_component_node(entity, flag)
	print("D: Registered Peer %s:%s with id %s" % [entity, entity.name, co_io_packets.io_peer.peer_id])
