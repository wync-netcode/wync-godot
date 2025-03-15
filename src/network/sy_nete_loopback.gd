extends System
class_name SyNeteLoopback
const label: StringName = StringName("SyNeteLoopback")

## Fake network that sends and receives packets between peers


func _ready():
	components = [CoIOPackets.label, CoPeerRegisteredFlag.label]
	super()

## NOTE: This system runs on "_on_process" (render frames)

func on_process_entity(entity: Entity, _data, delta: float):

	# components

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets

	#Loopback.system_send_receive(co_loopback.ctx, co_io_packets.io_peer, delta)
	Loopback.system_service(co_loopback.ctx)
