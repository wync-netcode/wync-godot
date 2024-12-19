extends System
class_name SyNetLerpPredicted
const label: StringName = StringName("SyNetLerpPredicted")

## This interpolation implementation applies:
## * Asumes there is no jitter
## * Uses packet arrival time as it's timestamp
## Drawbacks:
## * There will be visual glitches because of jitter


func _ready():
	components = [CoActor.label, CoActorRenderer.label, CoNetConfirmedStates.label, CoNetPredictedStates.label]
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
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?
	var frame = (1000.0 / physics_fps)
	var target_time = curr_time - pkt_inter_arrival_time - frame
	#var target_tick = co_ticks.server_ticks - (co_predict_data.latency_stable / frame)
	var target_tick = co_ticks.server_ticks - co_predict_data.tick_offset

	# interpolate entities

	for entity: Entity in entities:
		
		target_time = curr_time - pkt_inter_arrival_time - frame

		var co_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer

		# find two snapshots

		var snap_left: NetTickData = null
		var snap_right: NetTickData = null
		var found_snapshots = false

		# check if it has predicted states

		var has_co_net_predicted_states = entity.has_component(CoNetPredictedStates.label)
		if has_co_net_predicted_states:
			var co_net_predicted_states = entity.get_component(CoNetPredictedStates.label) as CoNetPredictedStates
			if co_net_predicted_states != null && co_net_predicted_states.prev.data != null:
				snap_left = co_net_predicted_states.prev
				snap_right = co_net_predicted_states.curr
				found_snapshots = true
				target_time = curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps)

		# else fall back to using confirmed state

		if not found_snapshots:
			var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
			var ring = co_net_confirmed_states.buffer
			
			# find the closest two snapshots around the target_tick
			# TODO: In case of not finding it fallback to _dead reckoning extrapolation_
			Log.out(self, "Comparing ticks start")
			for i in range(ring.size):
				var snapshot = ring.get_relative(-i) as NetTickData
				if not snapshot:
					break
				Log.out(self, "Comparing ticks %s %s" % [snapshot.tick, target_tick])
				if snapshot.tick >= target_tick:
					snap_right = snapshot
				elif snap_right != null && snapshot.timestamp < target_tick:
					found_snapshots = true
					snap_left = snapshot
					break
			
			"""
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
					break"""

		if not found_snapshots:
			Log.out(self, "left: %s | target: %s | right: %s | curr: %s" % [0, target_time, 0, curr_time])
			continue
		#else: Log.out(self, "left: %s | target: %s | right: %s | curr: %s" % [snap_left.timestamp, target_time, snap_right.timestamp, curr_time])
		# Log.out(self, "%s new_pos: %s | left: %s | target: %s | right: %s | curr: %s" % [snap_left.tick == snap_right.tick, new_pos, snap_left.timestamp, target_time, snap_right.timestamp, curr_time])

		# interpolate between the two

		"""
		var left_timestamp = \
			co_predict_data.last_tick_timestamp \
			+ (snap_left.tick - co_predict_data.last_tick_confirmed) \
			* (1000.0 / physics_fps)
		var right_timestamp = \
			co_predict_data.last_tick_timestamp \
			+ (snap_right.tick - co_predict_data.last_tick_confirmed) \
			* (1000.0 / physics_fps)
		"""
		# TODO: Determine if it's needed to keep the previous step for non-predicted interpolation
		# TODO: Why is there a difference of two ticks?
		var left_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_left.tick+2, co_ticks, co_predict_data)
		var right_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_right.tick+2, co_ticks, co_predict_data)
		
		
		if abs(left_timestamp - right_timestamp) < 0.000001:
			co_renderer.global_position = snap_right.data.position
		else:
			var left_pos = snap_left.data.position as Vector2
			var right_pos = snap_right.data.position as Vector2
			var factor = clampf(
				(float(target_time) - left_timestamp) / (right_timestamp - left_timestamp),
				0, 1)
			var new_pos = left_pos.lerp(right_pos, factor)
			co_renderer.global_position = new_pos
			
			#Log.out(self, "leftardiff %s | left: %s | target: %s | right: %s | factor %s ||| target_time_offset %s" % [target_time - left_timestamp, left_timestamp, target_time, right_timestamp, factor, co_predict_data.target_time_offset])
