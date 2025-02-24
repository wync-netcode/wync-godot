extends System
class_name SyNetLatencyStable
const label: StringName = StringName("SyNetLatencyStable")

## * Responsible for calculating a stable latency value
## * Uses a sliding window to calculate the mean from the latest values 


func on_process(_entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback", Log.TAG_LATENCY)
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_predict_data = wync_ctx.co_predict_data
	var co_ticks = wync_ctx.co_ticks
	var physics_fps = Engine.physics_ticks_per_second
	
	# Poll latency
	if co_ticks.ticks % ceili(float(physics_fps) / 2) == 0:
		co_predict_data.latency_buffer[co_predict_data.latency_buffer_head % co_predict_data.LATENCY_BUFFER_SIZE] = co_loopback.latency
		co_predict_data.latency_buffer_head += 1
		
		# sliding window mean
		var counter = 0
		var accum = 0
		var mean = 0
		for lat in co_predict_data.latency_buffer:
			if lat == 0:
				continue
			counter += 1
			accum += lat
		mean = ceil(float(accum) / counter)
		
		Log.out("latencyme mean diff %s %s %s >? %s" % [co_predict_data.latency_mean, mean, abs(mean - co_predict_data.latency_mean), co_predict_data.latency_std_dev], Log.TAG_LATENCY)
		
		# if new mean is outside range, then update everything
		# NOTE: Currently this doesn't cover the case of a highly volatile std_dev (i.e. that is stable then unstable). However this case is so rare it might be not worth even supporting it. Although it should'nt be too hard.
		
		if abs(mean - co_predict_data.latency_mean) > co_predict_data.latency_std_dev || counter < co_predict_data.LATENCY_BUFFER_SIZE:
			
			co_predict_data.latency_mean = mean
			
			# calculate std dev
			accum = 0
			for lat in co_predict_data.latency_buffer:
				if lat == 0:
					continue
				accum += (lat - co_predict_data.latency_mean) ** 2
			co_predict_data.latency_std_dev = ceil(sqrt(accum / counter)) 
			co_predict_data.latency_stable = co_predict_data.latency_mean + co_predict_data.latency_std_dev * 2
			
			# NOTE: Allow for choosing a latency stabilization strategy:
			# e.g. none (for using directly what the transport tells), std_dev, or 95th Qu
			
			Log.out("latencyme stable updated to %s | mean %s | stddev %s | acum %s" % [co_predict_data.latency_stable, co_predict_data.latency_mean, co_predict_data.latency_std_dev, accum], Log.TAG_LATENCY)
