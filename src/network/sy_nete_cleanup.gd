extends System
class_name SyNeteCleanup
const label: StringName = StringName("SyNeteCleanup")

## Clears the incoming packet buffer


func _ready():
	components = [ CoIOPackets.label ]
	super()


func on_process_entity(entity, _data, _delta: float):
	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets
	co_io.in_packets.clear()
