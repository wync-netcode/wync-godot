extends System
class_name SyNeteCleanup
const label: StringName = StringName("SyNeteCleanup")

## Clears the incoming packet buffer


func _ready():
	components = [ CoIOPackets.label ]
	super()


func on_process(entities, _data, _delta: float):
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not single_client:
		Log.err(self, "No single_client")
		return
	var co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets
	co_io.in_packets.clear()
