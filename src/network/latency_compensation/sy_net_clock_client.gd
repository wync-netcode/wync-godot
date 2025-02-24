extends System
class_name SyNetClockClient
const label: StringName = StringName("SyNetClockClient")

## Receives the clock sync packet, to be able to translate timestamps from
## the remote clock to the local clock


func _ready():
	components = [CoNetConfirmedStates.label, CoActor.label, CoActorRegisteredFlag.label]
	super()
	

func on_process(_entities, _data, _delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = wync_ctx.co_ticks

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err("Couldn't find singleton EnSingleClient", Log.TAG_CLOCK)
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets
	if co_io.in_packets.size() == 0:
		return

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as NetPacketClock
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)

		var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
		var physics_fps = Engine.physics_ticks_per_second
		var server_time_diff = (data.time + data.latency) - curr_time
	
		# calculate mean
		
		co_predict_data.clock_packets_received += 1
		co_predict_data.clock_offset_accumulator += server_time_diff
		co_predict_data.clock_offset_mean = (co_predict_data.clock_offset_mean * (co_predict_data.clock_packets_received-1) + server_time_diff) / co_predict_data.clock_packets_received
		
		# update ticks
		
		var current_server_time: float = curr_time + co_predict_data.clock_offset_mean
		var time_since_packet_sent: float = current_server_time - data.time
		
		if co_predict_data.clock_packets_received < 11:
			co_ticks.server_ticks = data.tick \
			+ round(time_since_packet_sent / (1000.0 / physics_fps))
			co_ticks.server_ticks_offset = co_ticks.server_ticks - co_ticks.ticks
			
		elif not co_ticks.server_ticks_offset_initialized:
			co_ticks.server_ticks_offset_initialized = true
			co_ticks.server_ticks = co_ticks.ticks + co_ticks.server_ticks_offset
			# TODO: Allow for updating co_ticks.server_ticks_offset every minute or so


		var server_ticks = %CoSingleWyncContext.ctx.co_ticks.ticks -1
		
		Log.out("Servertime %s, real %s, d %s | ticks %s, real %s, d %s | latency %s | clock %s | %s | %s | %s" % [
			int(current_server_time),
			Time.get_ticks_msec(),
			str(Time.get_ticks_msec() - current_server_time).pad_zeros(2).pad_decimals(1),
			co_ticks.server_ticks,
			server_ticks,
			server_ticks - co_ticks.server_ticks,
			Time.get_ticks_msec() - data.time,
			str(co_predict_data.clock_offset_mean).pad_decimals(2),
			str(time_since_packet_sent).pad_decimals(2),
			str(time_since_packet_sent / (1000.0 / physics_fps)).pad_decimals(2),
			co_ticks.server_ticks_offset,
		], Log.TAG_CLOCK)
