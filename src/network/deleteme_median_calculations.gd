extends System


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
	
	# TODO
	# 1. Definir la cantidad de tiempo en el pasado a mostrar e.g. ticks(RTT) + 1 tick
	
	var tick_rate = 60 # TODO: Extract from engine or define elsewhere
	var latency_in_ticks = ceil(co_loopback.lag / (1000.0 / tick_rate)) + 1

	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	co_snapshots.pkt_inter_arrival_time = ((1000.0 / 60) * 10) 

	# TODO: How to define the padding?
	var padding = 0
	var time_to_render = curr_time - co_snapshots.pkt_inter_arrival_time - padding

	# 2. Ensure we are receiving snapshots in order
	# 3. Calculate the position based on stored snapshots
	# 4. Apply it

	# Calculate mean packet inter arrival time

	for pkt: NetPacket in co_io.in_packets:

		pass

		"""
		Log.out(self, "latency_in_ticks %s : mean %s : diff_time %s" % [latency_in_ticks, co_snapshots.mean_pkt_inter_arrival_time, curr_time - co_snapshots.time_last_pkt_received])

		# precise mean calculation (float)
		co_snapshots.amount_pkts_received += 1

		if co_snapshots.amount_pkts_received >= 2:
			var diff_time = curr_time - co_snapshots.time_last_pkt_received

			if co_snapshots.amount_pkts_received == 2:
				co_snapshots.mean_pkt_inter_arrival_time = diff_time
			else:
				var prev_mean = co_snapshots.mean_pkt_inter_arrival_time
				var prev_count = co_snapshots.amount_pkts_received -1
				var new_count = prev_count +1

				co_snapshots.mean_pkt_inter_arrival_time = (prev_mean * prev_count + diff_time) / new_count

		co_snapshots.time_last_pkt_received = curr_time
		"""

		"""
		# precise mean calculation (integer)
		var diff_time = curr_time - co_snapshots.time_last_pkt_received
		co_snapshots.amount_pkts_received += 1

		if co_snapshots.amount_pkts_received >= 2:

			co_snapshots.sum_pkt_inter_arrival_time += diff_time
			# Compensate for not counting the first interval
			co_snapshots.mean_pkt_inter_arrival_time = co_snapshots.sum_pkt_inter_arrival_time / (co_snapshots.amount_pkts_received -1)

		co_snapshots.time_last_pkt_received = curr_time
		"""

	co_io.in_packets.clear()
