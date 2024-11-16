extends System
class_name SyNetInterpolation
const label: StringName = StringName("SyNetInterpolation")

## This interpolation implementation applies:
## * Asumes there is no jitter
## * Uses packet arrival time as it's timestamp
## Drawbacks:
## * There will be visual glitches because of jitter


func _ready():
	components = [CoNetConfirmedStates.label, CoActor.label, CoCollider.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return

	var curr_time = Time.get_ticks_msec()
	var physics_fps = Engine.physics_ticks_per_second
	
	# define target time to render
	# TODO: Extract from engine or define elsewhere
	var tick_rate = physics_fps
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?
	var padding = (1000.0 / tick_rate)
	var target_time = curr_time - pkt_inter_arrival_time - padding

	# interpolate entities

	for entity: Entity in entities:

		var co_collider = entity.get_component(CoCollider.label) as CoCollider

		# find two snapshots

		var snap_left: NetTickData = null
		var snap_right: NetTickData = null
		var found_snapshots = false

		# check if it has predicted states

		var co_net_predicted_states = entity.get_component(CoNetPredictedStates.label) as CoNetPredictedStates
		if co_net_predicted_states != null:
			if co_net_predicted_states.prev != null:
				snap_left = co_net_predicted_states.prev
				snap_right = co_net_predicted_states.curr
				found_snapshots = true

				target_time = curr_time + co_loopback.lag + padding

		# else fall back to using confirmed state

		else:
			
			var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
			var ring = co_net_confirmed_states.buffer

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
		# Log.out(self, "%s new_pos: %s | left: %s | target: %s | right: %s | curr: %s" % [snap_left.tick == snap_right.tick, new_pos, snap_left.timestamp, target_time, snap_right.timestamp, curr_time])

		# interpolate between the two

		if abs(snap_left.timestamp - snap_right.timestamp) < 0.000001:
			co_collider.global_position = snap_right.data.position
		else:
			var new_pos = (snap_left.data.position as Vector2).lerp((snap_right.data.position as Vector2), (target_time - snap_left.timestamp) / (snap_right.timestamp - snap_left.timestamp))
			co_collider.global_position = new_pos
