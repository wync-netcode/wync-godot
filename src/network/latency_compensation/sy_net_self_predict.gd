extends System
class_name SyNetSelfPredict

## * Simple extrapolation using last two confirmed positions


func _ready():
	# Components from SyActorMovement
	# components = "CoActor,CoVelocity,CoCollider,CoActorInput"
	components = "%s,%s,%s,%s" % [CoNetConfirmedStates.label, CoNetPredictedStates.label, CoFlagNetSelfPredict.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	var curr_time = Time.get_ticks_msec()
	
	# define target time to render

	# TODO: Extract from engine or define elsewhere
	var tick_rate = 60.0 / 10.0
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	#var pkt_inter_arrival_time = ((1000.0 / 60) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?
	var padding = (1000.0 / tick_rate)
	#var target_time = curr_time - pkt_inter_arrival_time - padding
	var target_time = curr_time + co_loopback.lag + (1000.0 / 60)

	#var target_tick = co_predict_data.last_tick_confirmed + ceil((target_time - curr_time) / tick_rate)
	var target_tick = co_predict_data.last_tick_confirmed + ceil((target_time - co_predict_data.last_tick_timestamp) / float(1000.0 / 60))

	#Log.out(self, "target_time %s last_tick %s target_tick %s" % [target_time, co_predict_data.last_tick_confirmed, target_tick])

	# interpolate entities ????


	for entity: Entity in entities:
		
		var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
		var co_net_predicted_states = entity.get_component(CoNetPredictedStates.label) as CoNetPredictedStates
		var co_net_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# Reset them
		# TODO: Move this elsewhere
		#if co_net_predicted_states.curr == null && co_net_confirmed_states.buffer.get_relative(-1) != null:
		if co_net_confirmed_states.buffer.get_relative(-1) != null:
			var curr_confirmed = co_net_confirmed_states.buffer.get_relative(0) as NetTickData
			var prev_confirmed = co_net_confirmed_states.buffer.get_relative(-1) as NetTickData
			co_net_predicted_states.curr = curr_confirmed.copy()
			co_net_predicted_states.prev = prev_confirmed.copy()

			if abs(curr_confirmed.timestamp - prev_confirmed.timestamp) < 0.000001:
				print("Break")
		if co_net_predicted_states.curr == null:
			Log.out(self, "co_net_predicted_states.curr == null")
			continue

		"""
		"""

		var curr_predicted = co_net_predicted_states.curr as NetTickData
		var prev_predicted = co_net_predicted_states.prev as NetTickData

		if curr_predicted.data.position != Vector2.ZERO:
			Log.out(self, "curr_predicted %s" % curr_predicted.data.position)
			print("break")
		#var position: Vector2 = curr_confirmed.data as Vector2
		#var velocity: Vector2 = (curr_confirmed.data as Vector2) - (curr_confirmed.data as Vector2)
		var velocity: Vector2

		var simulated_ticks: int = 0

		var collider = entity.get_component(CoCollider.label) as CoCollider
		collider.global_position = (co_net_confirmed_states.buffer.get_relative(0) as NetTickData).data.position as Vector2
		collider.velocity        = (co_net_confirmed_states.buffer.get_relative(0) as NetTickData).data.velocity as Vector2

		for tick in range(curr_predicted.tick +1, target_tick +1):

			# predicting state here
			var input = co_net_buffered_inputs.get_tick(tick)
			if input:
				simulated_ticks += 1
				prev_predicted.data.position = curr_predicted.data.position
				prev_predicted.data.velocity = curr_predicted.data.velocity

				# reset to previous state
				#Log.out(self, "confirmed position 1 %s" % [(co_net_confirmed_states.buffer.get_relative(0) as NetTickData).data as Vector2])
				#Log.out(self, "confirmed position 2 %s" % [(co_net_confirmed_states.buffer.get_relative(-1) as NetTickData).data as Vector2])
				SyActorMovement.simulate_movement(input, collider, _delta)
				#velocity = (curr_predicted.data as Vector2) - (prev_predicted.data as Vector2)
				curr_predicted.data.position = (collider as Node2D).global_position
				curr_predicted.data.velocity = (collider as Node as CharacterBody2D).velocity
			#velocity = (curr_predicted.data as Vector2) - (prev_predicted.data as Vector2)
			#prev_predicted.data = curr_predicted.data
			#curr_predicted.data += velocity
			# ====

			prev_predicted.timestamp += 1000.0 / 60
			curr_predicted.timestamp += 1000.0 / 60

			#Log.out(self, "Simulating tick %s prev_time %s curr_time %s" % [tick, prev_predicted.timestamp, curr_predicted.timestamp])
			#curr_predicted.timestamp = co_predict_data.last_tick_timestamp + (tick_diff)

		Log.out(self, "Simulated %s ticks out of %s" % [simulated_ticks, target_tick - curr_predicted.tick])


		# calculate ticks and timestamp
		prev_predicted.tick = target_tick -1
		curr_predicted.tick = target_tick
		#prev_predicted.timestamp = 0
		#curr_predicted.timestamp = co_predict_data.last_tick_timestamp + (tick_diff)


			

		"""
		# find two snapshots

		var snap_left: NetTickData = null
		var snap_right: NetTickData = null
		var found_snapshots = false

		# find the closest two snapshots around the target time

		for i in range(ring.size):
			var snapshot = ring.get_relative(-i)	
			if not snapshot:
				break
			if snapshot.timestamp > target_time:
				snap_right = snapshot
			elif snap_right != null && snapshot.timestamp < target_time:
				found_snapshots = true
				snap_left = snapshot
				break

		if not found_snapshots:
			Log.out(self, "left: %s | target: %s | right: %s | curr: %s" % [0, target_time, 0, curr_time])
			continue
		#else: Log.out(self, "left: %s | target: %s | right: %s | curr: %s" % [snap_left.timestamp, target_time, snap_right.timestamp, curr_time])

		# interpolate between the two

		var new_pos = (snap_left.data as Vector2).lerp((snap_right.data as Vector2), (target_time - snap_left.timestamp) / (snap_right.timestamp - snap_left.timestamp))
		(entity as Node as Node2D).position = new_pos
		"""
