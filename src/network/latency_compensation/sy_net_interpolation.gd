extends System
class_name SyNetInterpolation

## This interpolation implementation applies:
## * Asumes there is no jitter
## * Uses packet arrival time as it's timestamp
## Drawbacks:
## * There will be visual glitches because of jitter


func _ready():
	components = "%s,%s,%s" % [CoNetConfirmedStates.label, CoActor.label, CoCollider.label]
	super()
	

func on_process(entities, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return

	var curr_time = Time.get_ticks_msec()
	
	# define target time to render
	# TODO: Extract from engine or define elsewhere
	var tick_rate = 60 
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	var pkt_inter_arrival_time = ((1000.0 / 60) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?
	var padding = (1000.0 / tick_rate)
	var target_time = curr_time - pkt_inter_arrival_time - padding

	# interpolate entities

	for entity: Entity in entities:
		
		var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
		var ring = co_net_confirmed_states.buffer

		# find two snapshots

		var snap_left: CoNetConfirmedStates.TickData = null
		var snap_right: CoNetConfirmedStates.TickData = null
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
