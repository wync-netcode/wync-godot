extends System
class_name SyClientPktInterpolation

## This interpolation implementation applies:
## * Asumes there is no jitter
## * Uses packet arrival time as it's timestamp
## Drawbacks:
## * There will be visual glitches because of jitter



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
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return
	var co_snapshots = entity.get_component(CoSnapshots.label) as CoSnapshots
	var curr_time = Time.get_ticks_msec()

	# Save the packet data to their respective position buffers by actors id

	if co_io.in_packets.size() > 0:

		for pkt: NetPacket in co_io.in_packets:
			var data = pkt.data as NetSnapshot
			for i in range(data.entity_ids.size()):
				var actor_id = data.entity_ids[i]
				var position = data.positions[i]

				var snapshot = PositionSnapshot.new()
				snapshot.position = position
				snapshot.timestamp = curr_time
				
				if not co_snapshots.entity_snapshots.has(actor_id):
					co_snapshots.entity_snapshots[actor_id] = RingBuffer.new(4)

				var ring = co_snapshots.entity_snapshots[actor_id]
				ring.push(snapshot)

		co_io.in_packets.clear()
	
	# TODO
	# 1. Definir la cantidad de tiempo en el pasado a mostrar e.g. ticks(RTT) + 1 tick
	
	var tick_rate = 60 # TODO: Extract from engine or define elsewhere

	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	co_snapshots.pkt_inter_arrival_time = ((1000.0 / 60) * 10) 

	# TODO: How to define the padding? Maybe it should be a tick?
	var padding = 0
	var time_to_render = curr_time - co_snapshots.pkt_inter_arrival_time - padding

	# 2. find two snapshots

	var target_time = time_to_render

	#for snapshot in co_snapshots.entity_snapshots[actor_id]
	for actor_entity in co_actors.actors:
		if not actor_entity:
			continue
		var co_actor = actor_entity.get_component(CoActor.label) as CoActor

		if not co_snapshots.entity_snapshots.has(co_actor.id):
			continue

		var ring = co_snapshots.entity_snapshots[co_actor.id] as RingBuffer

		# find two snapshots

		var snap_left: PositionSnapshot = null
		var snap_right: PositionSnapshot = null
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
		else:
			Log.out(self, "left: %s | target: %s | right: %s | curr: %s" % [snap_left.timestamp, target_time, snap_right.timestamp, curr_time])

		#Sesión 2 11:30
		# interpolate between the two

		var new_pos = snap_left.position.lerp(snap_right.position, (target_time - snap_left.timestamp) / (snap_right.timestamp - snap_left.timestamp))
		(actor_entity as Node2D).position = new_pos




	# 3. Calculate the position based on stored snapshots
	# 4. Apply it

