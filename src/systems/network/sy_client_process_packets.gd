extends System
class_name SyClientProcessPackets


func _ready():
	components = "%s,%s,%s" % [CoClient.label, CoIOPackets.label, CoSnapshots.label]
	super()
	

func on_process_entity(entity: Entity, _delta: float):
	var co_client = entity.get_component(CoClient.label) as CoClient
	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets

	for pkt: NetPacket in co_io.in_packets:
		co_io.in_packets.erase(pkt)

		if pkt.data.positions.size():
			print("Client %s received data: %s " % [co_io.peer_id, pkt.data.positions[0]])
