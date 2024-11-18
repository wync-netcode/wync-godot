extends System
class_name SyNetReceiveInputs
const label: StringName = StringName("SyNetReceiveInputs")

## * Buffers the inputs per tick


func _ready():
	components = [CoActor.label, CoActorInput.label, CoActorRegisteredFlag.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var en_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not en_server:
		Log.err(self, "Couldn't find singleton EnSingleServer")
		return
	var co_io_packets = en_server.get_component(CoIOPackets.label) as CoIOPackets

	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		Log.err(self, "Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	# look entity id in the packets and save accordingly to buffer

	var packets_to_remove = []
	for pkt: NetPacket in co_io_packets.in_packets:
		var data = pkt.data as NetPacketInputs
		if not data:
			continue
		packets_to_remove.append(pkt)

		#Log.out(self, "co_io_packets.in_packets.size() %s" % co_io_packets.in_packets.size())
		#Log.out(self, "data.inputs %s" % [data.inputs])

		var actor_id = data.actor_id
		if actor_id >= co_actors.actors.size():
			continue

		var actor_entity = co_actors.actors[actor_id] as Entity
		if not actor_entity:
			Log.err(self, "Couldn't find actor with id %s" % actor_id)
			continue

		if not actor_entity.has_component(CoNetBufferedInputs.label):
			Log.err(self, "Actor doesn't have component CoNetBufferedInputs")
			continue
		var co_buffered_inputs = actor_entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# iterate all inputs

		for input: CoActorInput in data.inputs:
			co_buffered_inputs.set_tick(input.tick, input.copy())

			if input == data.inputs[-1]:
				#Log.out(self, "Inputs received movement %s (tick %s)" % [input.movement_dir, input.tick])
				pass

	# remove consumed packets

	for pkt in packets_to_remove:
		co_io_packets.in_packets.erase(pkt)

	# apply inputs to player

	for entity: Entity in entities:

		var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
		var co_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# check if we have an input for that frame

		var input = co_buffered_inputs.get_tick(co_ticks.ticks)
		if input is CoActorInput:
			input.copy_to_instance(co_actor_input)
		else:
			#Log.out(self, "Didn't find input for tick %s" % [co_ticks.ticks])
			pass
