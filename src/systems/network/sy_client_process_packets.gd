extends System
class_name SyClientProcessPackets


func _ready():
	components = "%s,%s,%s" % [CoClient.label, CoIOPackets.label, CoSnapshots.label]
	super()
	

func on_process_entity(entity: Entity, _delta: float):
	var co_io = entity.get_component(CoIOPackets.label) as CoIOPackets
	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors
	

	for pkt: NetPacket in co_io.in_packets:

		# TODO: proper packet checking
		if pkt.data.positions.size() != pkt.data.entity_ids.size():
			continue

		for id in pkt.data.entity_ids:
			var actor = co_actors.actors[id]
			if not actor:
				print("W: Couldn't find actor with id %s" % id)
				continue

			if actor is not Node2D:
				continue

			(actor as Node2D).position = pkt.data.positions[id]
	
	co_io.in_packets.clear()
