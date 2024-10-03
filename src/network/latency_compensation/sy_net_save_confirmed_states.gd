extends System
class_name SyNetSaveConfirmedStates

"""
Components:
* (Data)    NetTickData
* (Storage) CoNetConfirmedStates
				RingBuffer[NetTickData]
* (Storage) CoNetPredictedStates
				RingBuffer[NetTickData]
# (Storage) CoNetBufferedInputs
				Array[tick_id: int, input: Input]

* (Flag)    CoFlagNetExtrapolate
* (Flag)    CoFlagSelfPredict

Systems:
* (Gather/Generation) SyNetSaveConfirmedStates (CoNetConfirmedStates)
* (Gather/Generation) SyNetExtrapolate (CoNetConfirmedStates, CoNetPredictedStates, CoNetExtrapolate)
* (Gather/Generation) SyNetSelfPredict (CoNetConfirmedStates, CoNetPredictedStates, CoSelfPredict, CoNetBufferedInputs)
* (Display) SyNetInterpolate (CoNetConfirmedStates || CoNetPredictedStates)
"""


func _ready():
	components = "%s,%s,%s,%s" % [CoNetConfirmedStates.label, CoActor.label, CoCollider.label, CoActorRegisteredFlag.label]
	super()
	

func on_process(_entities, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err(self, "Couldn't find singleton EnSingleClient")
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets

	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		Log.err(self, "Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	var curr_time = Time.get_ticks_msec()

	# save tick data from packets

	for pkt: NetPacket in co_io.in_packets:
		var data = pkt.data as NetSnapshot
		if not data:
			continue

		for i in range(data.entity_ids.size()):
			var actor_id = data.entity_ids[i]
			var actor_entity = co_actors.actors[actor_id] as Entity
			if not actor_entity:
				Log.err(self, "Couldn't find actor with id %s" % actor_id)
				continue

			var tick_data = NetTickData.new()
			tick_data.tick = data.tick
			tick_data.timestamp = curr_time
			tick_data.data = data.positions[i]

			var co_net_confirmed_states = actor_entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
			var ring = co_net_confirmed_states.buffer
			ring.push(tick_data)

	co_io.in_packets.clear()
