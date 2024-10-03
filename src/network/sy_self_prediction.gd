class_name SySelfPrediction
extends System

## Procedure:
## * Have a ring buffer to store tick data: tick, snapshot, input

## * Each time a tick is received:
## * Determine the amount of ticks to predict forward, based on _target time_, RTT and padding
## * Overwrite the predicted tick data with the server data. (Use a special ring buffer than can behave like and array for accessing ticks like ints)
## * Repredict all ticks from the last confirmed tick

## * Every graphic frame:
## * Poll inputs for next tick
## * Determine the _target time_ based on last confirmed tick, delta, RTT, and padding
## * If there is no tick with time greater than _target time_ predict one tick forward
## * Find nearest two snapshots around _target time_
## * Set entity interpolated position using the _target time_

## Drawbacks:
## * Maybe the game developer doesn't want interpolation on his local prediction
## * Since we don't have tick info, we cannot sent inputs in bulk to the server

"""
Self-Prediction and Extrapolation (Dead Reckoning)

Self-Prediction should always be implemented alongside extrapolation?
"""

"""
Singletons
	CoSingleSelfPredictedActors
		var actors: List[Actors]
		var actor_snapshot: Array[Dictionary[actor_id, Snapshot]]
	CoSingleClient
Entities
	Player
		CoPlayerInput
		CoSelfPredicted
		CoSelfPredictedRegistered
Systems
	SySelfPrediction # Handle packets && Handle entity positions and prediction
	SySelfPredictionRegister # Registers actors that will be predicted
"""


func _ready():
	components = "%s,%s,%s,%s" % [CoActor.label, CoActorInput.label, CoSelfPredicted.label, CoSelfPredictedRegistered.label]
	super()


func on_process(entities: Array[Entity], _delta: float):

	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not single_client:
		print("E: Couldn't find singleton EnSingleClient")
		return
	var co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets
	var co_client = single_client.get_component(CoServer.label) as CoClient

	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		print("E: Couldn't find singleton EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return
	
	var co_single_self_predicted_actors = ECS.get_singleton_component(self, CoSingleSelfPredictedActors.label) as CoSingleSelfPredictedActors
	var curr_time = Time.get_ticks_msec()

	# calculate ticks to predict

	var logic_tick_rate = 1000.0/60
	var padding = 1000.0/60
	var target_time = int((co_loopback.lag) + padding)
	var ticks_to_predict = ceil(target_time / logic_tick_rate)
	co_single_self_predicted_actors.ticks_to_predict = ticks_to_predict

	# check server new snapshot data

	if co_io.in_packets.size() > 0:

		for pkt: NetPacket in co_io.in_packets:
			var data = pkt.data as NetSnapshot
			if not data:
				continue

			var tick_data = CoSingleSelfPredictedActors.TickData.new()
			tick_data.tick = data.tick
			tick_data.timestamp = curr_time ## TODO: Implement incoming delay or some other anti-jitter measure

			for i in range(data.entity_ids.size()):
				var actor_id = data.entity_ids[i]
				var position = data.positions[i]

				# Save this snapshot data

				# Create tick data

				var snapshot = PositionSnapshot.new()
				snapshot.position = position
				snapshot.timestamp = curr_time


				# Add to buffer

				co_single_self_predicted_actors.snapshots_set_tick(tick_data.tick, tick_data)
				co_single_self_predicted_actors.last_tick_confirmed = tick_data.tick

		co_io.in_packets.clear()

	# 
		
	for entity in entities:
		pass

