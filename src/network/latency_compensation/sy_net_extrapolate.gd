extends System
class_name SyNetExtrapolate
const label: StringName = StringName("SyNetExtrapolate")

## * Simple extrapolation using last two confirmed positions


func _ready():
	components = [CoNetConfirmedStates.label, CoNetPredictedStates.label, CoFlagNetExtrapolate.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second
	
	# define target time to render

	# TODO: Extract from engine or define elsewhere
	var tick_rate = physics_fps / 10.0
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	#var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?
	var padding = (1000.0 / tick_rate)
	#var target_time = curr_time - pkt_inter_arrival_time - padding
	var target_time = curr_time + co_loopback.lag + (1000.0 / physics_fps)

	#var target_tick = co_predict_data.last_tick_confirmed + ceil((target_time - curr_time) / tick_rate)
	var target_tick = co_predict_data.last_tick_confirmed + ceil((target_time - co_predict_data.last_tick_timestamp) / float(1000.0 / physics_fps))

	Log.out(self, "target_time %s last_tick %s target_tick %s" % [target_time, co_predict_data.last_tick_confirmed, target_tick])

	# interpolate entities

	for entity: Entity in entities:
		
		var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
		var co_net_predicted_states = entity.get_component(CoNetPredictedStates.label) as CoNetPredictedStates

		# Initialize them
		# TODO: Move this elsewhere
		#if co_net_predicted_states.curr == null && co_net_confirmed_states.buffer.get_relative(-1) != null:
		if co_net_confirmed_states.buffer.get_relative(-1) != null:
			var curr_confirmed = co_net_confirmed_states.buffer.get_relative(0) as NetTickData
			var prev_confirmed = co_net_confirmed_states.buffer.get_relative(-1) as NetTickData
			co_net_predicted_states.curr = curr_confirmed.copy()
			co_net_predicted_states.prev = prev_confirmed.copy()
		if co_net_predicted_states.curr == null:
			continue

		"""
		"""

		var curr_predicted = co_net_predicted_states.curr as NetTickData
		var prev_predicted = co_net_predicted_states.prev as NetTickData

		#var position: Vector2 = curr_confirmed.data as Vector2
		#var velocity: Vector2 = (curr_confirmed.data as Vector2) - (curr_confirmed.data as Vector2)
		var velocity: Vector2

		for tick in range(curr_predicted.tick +1, target_tick +1):

			velocity = (curr_predicted.data as Vector2) - (prev_predicted.data as Vector2)

			prev_predicted.data = curr_predicted.data
			curr_predicted.data += velocity

			prev_predicted.timestamp += 1000.0 / physics_fps
			curr_predicted.timestamp += 1000.0 / physics_fps

			Log.out(self, "Simulating tick %s prev_time %s curr_time %s" % [tick, prev_predicted.timestamp, curr_predicted.timestamp])
			#curr_predicted.timestamp = co_predict_data.last_tick_timestamp + (tick_diff)


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
