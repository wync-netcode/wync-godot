extends System
class_name SyNeteCleanup
const label: StringName = StringName("SyNeteCleanup")

## Clears the incoming packet buffer


func _ready():
	components = [ CoIOPackets.label ]
	super()


func on_process_entity(entity, _data, _delta: float):
	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets

	#if co_io.in_packets.size():
	#	Log.out(self, "peer_id(%s) Didn't consume (%s) Packets" % [co_io.peer_id, co_io.in_packets.size()])
	#	for k in range(co_io.in_packets.size()-1, -1, -1):
	#		var pkt = co_io.in_packets[k] as NetPacket
	#		Log.out(self, "%s:%s" % [pkt.data, HashUtils.object_to_dictionary(pkt.data)])

	co_io.io_peer.in_packets.clear()
