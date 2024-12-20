extends System
class_name SyNetSaveConfirmedStates
const label: StringName = StringName("SyNetSaveConfirmedStates")

"""
(OUTDATED)
Components:
* (Data)    CoSingleNetPredictionData
				pkt_inter_arrival_time: int
				last_tick_confirmed: int

* (Data)    NetTickData
* (Storage) CoNetConfirmedStates
				RingBuffer[NetTickData]
* (Storage) CoNetPredictedStates
				curr: NetTickData
				prev: NetTickData
# (Storage) CoNetBufferedInputs
				Array[tick_id: int, input: Input]

* (Flag)    CoFlagNetExtrapolate
* (Flag)    CoFlagSelfPredict

Systems:
* (Gather/Generation) SyNeyBufferInputs (CoFlagSelfPredict, CoNetBufferedInputs)
* (Gather/Generation) SyNetSaveConfirmedStates (CoNetConfirmedStates)
* (Gather/Generation) SyNetExtrapolate (CoNetConfirmedStates, CoNetPredictedStates, CoFlagNetExtrapolate)
* (Gather/Generation) SyNetSelfPredict (CoNetConfirmedStates, CoNetPredictedStates, CoFlagSelfPredict, CoNetBufferedInputs)
* (Display) SyNetInterpolate (CoNetConfirmedStates || CoNetPredictedStates)

TODO:
* A client system to send buffered inputs back to server
* A server system to receive and interpret (and store) player buffered inputs
* A way to ensure client and server ticks are synced.
"""
# TODO: This preferable would be in process


func _ready():
	components = [CoNetConfirmedStates.label, CoActor.label, CoActorRegisteredFlag.label]
	super()
	

func on_process(_entities, _data, _delta: float):

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

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as NetSnapshot
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
		#Log.out(self, "consume | co_io.in_packets.size() %s" % co_io.in_packets.size())

		for i in range(data.entity_ids.size()):
			var actor_id = data.entity_ids[i]
			var actor_entity = co_actors.actors[actor_id] as Entity
			if not actor_entity:
				Log.err(self, "Couldn't find actor with id %s" % actor_id)
				continue

			var tick_data = NetTickData.new()
			tick_data.tick = data.tick
			tick_data.timestamp = curr_time
			tick_data.data = CoCollider.SnapData.new()
			tick_data.data.position = data.positions[i]
			tick_data.data.velocity = data.velocities[i]

			#Log.out(self, "data.tick %s" % data.tick)

			var co_net_confirmed_states = actor_entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
			var ring = co_net_confirmed_states.buffer
			ring.push(tick_data)

	#Log.out(self, "consume | cleared co_io.in_packets.size() %s" % co_io.in_packets.size())
