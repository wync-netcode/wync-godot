class_name WyncClock

## ==================================================
## Private
## ==================================================

static func wync_handle_pkt_clock(ctx: WyncCtx, data: Variant):

	# see https://en.wikipedia.org/wiki/Cristian%27s_algorithm

	if data is not WyncPktClock:
		return 1
	data = data as WyncPktClock

	var co_ticks = ctx.co_ticks
	var co_predict_data = ctx.co_predict_data
	var curr_time = WyncClock.clock_get_ms(ctx)
	var physics_fps = ctx.physic_ticks_per_second
	var curr_clock_offset = (data.time + (curr_time - data.time_og) / 2.0) - curr_time

	# calculate mean
	# Note: To improve accurace modify _server clock sync_ throttling or sliding window size
	# Note: Use a better algorithm for calculating a stable long lasting value of the clock offset
	#   Resistant to sudden lag spikes. Look into 'Trimmed mean'

	co_predict_data.clock_offset_sliding_window.push(curr_clock_offset)

	var count: int = 0
	var acc: float = 0
	for i: int in range(co_predict_data.clock_offset_sliding_window.size):
		var i_clock_offset = co_predict_data.clock_offset_sliding_window.get_at(i)
		if i_clock_offset == 0:
			continue

		count += 1
		acc += i_clock_offset

	co_predict_data.clock_offset_mean = ceil(acc / count)
	var current_server_time: float = curr_time + co_predict_data.clock_offset_mean
	
	# update ticks

	var cal_server_ticks: float = (data.tick + ((curr_time - data.time_og) / 2.0) / (1000.0 / physics_fps))
	var new_server_ticks_offset: int = roundi(cal_server_ticks - co_ticks.ticks)

	# Note: needs further reviewing
	# to avoid fluctuations by one unit, always prefer the biggest value
	#if (abs(new_server_ticks_offset - co_ticks.server_tick_offset) == 1):
		#new_server_ticks_offset = max(co_ticks.server_tick_offset, new_server_ticks_offset)

	# Note: at the beggining 'server_ticks' will be equal to 0

	CoTicks.server_tick_offset_collection_add_value(co_ticks, new_server_ticks_offset)
	co_ticks.server_tick_offset = CoTicks.server_tick_offset_collection_get_most_common(co_ticks)
	co_ticks.server_ticks = co_ticks.ticks + co_ticks.server_tick_offset

	Log.out("Servertime %s, real %s, d %s | server_ticks_aprox %s | latency %s | clock %s | %s" % [
		int(current_server_time),
		Time.get_ticks_msec(),
		str(Time.get_ticks_msec() - current_server_time).pad_zeros(2).pad_decimals(1),
		co_ticks.server_ticks,
		Time.get_ticks_msec() - data.time,
		str(co_predict_data.clock_offset_mean).pad_decimals(2),
		co_ticks.server_tick_offset,
	])


# TODO: Fix divisions by zero
static func wync_system_stabilize_latency (ctx: WyncCtx, lat_info: WyncCtx.PeerLatencyInfo):
	
	# Poll latency
	if WyncMisc.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
		return

	lat_info.latency_buffer[
		lat_info.latency_buffer_head % WyncCtx.LATENCY_BUFFER_SIZE] = lat_info.latency_raw_latest_ms
	lat_info.latency_buffer_head += 1
	
	# sliding window mean
	var counter: int = 0
	var accum: int = 0
	var mean: int = 0
	for lat: int in lat_info.latency_buffer:
		if lat == 0:
			continue
		counter += 1
		accum += lat
	if counter == 0: return
	mean = ceil(float(accum) / counter)
	lat_info.debug_latency_mean_ms = float(accum) / counter
	
	# if new mean is outside range, then update everything
	
	if abs(mean - lat_info.latency_mean_ms) > lat_info.latency_std_dev_ms || counter < WyncCtx.LATENCY_BUFFER_SIZE:
		
		lat_info.latency_mean_ms = mean
		
		# calculate std dev
		accum = 0
		for lat in lat_info.latency_buffer:
			if lat == 0:
				continue
			accum += (lat - lat_info.latency_mean_ms) ** 2
		lat_info.latency_std_dev_ms = ceil(sqrt(accum / counter))

		# use 98th percentile (mean + 2*std_dev)
		lat_info.latency_stable_ms = lat_info.latency_mean_ms + lat_info.latency_std_dev_ms * 2
		
		# NOTE: Allow for choosing a latency stabilization strategy:
		# e.g. none (for using directly what the transport tells) or 98th perc
		
		Log.out("latencyme stable updated to %s | mean %s | stddev %s | acum %s" % [lat_info.latency_stable_ms, lat_info.latency_mean_ms, lat_info.latency_std_dev_ms, accum], Log.TAG_LATENCY)


static func wync_update_prediction_ticks (ctx: WyncCtx):
	
	var lat_info := ctx.peer_latency_info[WyncCtx.SERVER_PEER_ID]
	var co_predict_data := ctx.co_predict_data
	var co_ticks := ctx.co_ticks
	
	var curr_time: float = WyncClock.clock_get_ms(ctx)
	var physics_fps = Engine.physics_ticks_per_second

	# Adjust tick_offset_desired periodically to compensate for unstable ping
	
	if WyncMisc.fast_modulus(co_ticks.ticks, 32) == 0:

		co_predict_data.tick_offset_desired = ceil(lat_info.latency_stable_ms / (1000.0 / physics_fps)) + 2
		
		var target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
		var target_time = curr_time + co_predict_data.tick_offset_desired * (1000.0 / physics_fps)

		Log.out("co_predict_data.tick_offset_desired %s" % [co_predict_data.tick_offset_desired], Log.TAG_PRED_TICK)
		Log.out("Updating tick offset to %s" % co_predict_data.tick_offset, Log.TAG_PRED_TICK)
		Log.out("target_tick %s | target_time %s | with tick offset %s" % [target_tick, target_time, curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps) ], Log.TAG_PRED_TICK)
		Log.out("target_tick_timestamp %s" % [target_tick * (1000.0 / physics_fps) ], Log.TAG_PRED_TICK)

			
	# Smoothly transition tick_offset
	# NOTE: Should be configurable
	
	if co_predict_data.tick_offset_desired != co_predict_data.tick_offset:
		
		# up transition
		if co_predict_data.tick_offset_desired > co_predict_data.tick_offset:
			co_predict_data.tick_offset += 1
		# down transition
		else:
			if co_predict_data.tick_offset == co_predict_data.tick_offset_prev:
				co_predict_data.tick_offset -= 1
			else:
				# NOTE: Somehow I can't find another way to keep the prev updated
				co_predict_data.tick_offset_prev = co_predict_data.tick_offset

	# target_tick can only go forward. Use max so that we never go back
	var _prev_target_tick = co_predict_data.target_tick
	co_predict_data.target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
	co_predict_data.current_tick_timestamp = curr_time

	if (co_predict_data.target_tick - _prev_target_tick != 1):
		Log.outc(ctx, "couldn't find input | target tick changed badly %s %s" % [_prev_target_tick, co_predict_data.target_tick])

	#Log.outc(ctx, "prev_target_tick %s, new_target_tick %s" % [_prev_target_tick, co_predict_data.target_tick])
	
	#Log.out(self, "ticks local %s | net %s %s %s" % [co_ticks.ticks, co_ticks.server_ticks, co_predict_data.target_tick, co_ticks.ticks + co_ticks.server_ticks_offset])
	
	# ==============================================================
	# Setup the next tick-action-history
	# Run before any prediction takes places on the current tick
	# NOTE: This could be moved elsewhere
	
	WyncEventUtils.action_tick_history_reset(ctx, co_predict_data.target_tick)


static func wync_server_handle_clock_req(ctx: WyncCtx, data: Variant, from_nete_peer_id: int):
	
	if data is not WyncPktClock:
		return 1
	data = data as WyncPktClock

	var wync_peer_id = WyncJoin.is_peer_registered(ctx, from_nete_peer_id)
	if wync_peer_id < 0:
		Log.errc(ctx, "client %s is not registered" % from_nete_peer_id)
		return 3
	
	# prepare packet

	var packet = WyncPktClock.new()
	packet.time_og = data.time_og
	packet.tick_og = data.tick_og
	packet.tick = ctx.co_ticks.ticks
	packet.time = WyncClock.clock_get_ms(ctx)

	# queue for sending

	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_CLOCK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)


static func wync_client_ask_for_clock(ctx: WyncCtx):

	# Note: Maybe increase frequency when: beggining, or when detected high packet loss
	if WyncMisc.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
		return

	var packet = WyncPktClock.new()
	packet.time_og = WyncClock.clock_get_ms(ctx)
	packet.tick_og = ctx.co_ticks.ticks

	# prepare peer packet and send (queue)

	var result = WyncPacketUtil.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_CLOCK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)


## ==================================================
## Public
## ==================================================


static func wync_advance_ticks(ctx: WyncCtx):
	
	ctx.co_ticks.ticks += 1
	ctx.co_ticks.server_ticks += 1
	ctx.co_ticks.lerp_delta_accumulator_ms = 0


## set the latency this peer is experimenting (get it from your transport)
## @argument latency_ms: int. Latency in milliseconds
static func wync_peer_set_current_latency (ctx: WyncCtx, peer_id: int, latency_ms: int):
	ctx.peer_latency_info[peer_id].latency_raw_latest_ms = latency_ms


static func wync_client_set_physics_ticks_per_second (ctx: WyncCtx, tps: int):
	ctx.physic_ticks_per_second = tps


static func clock_set_debug_time_offset(ctx: WyncCtx, time_offset_ms: int):
	ctx.co_ticks.debug_time_offset_ms = time_offset_ms


static func clock_get_ms(ctx: WyncCtx) -> float:
	return float(Time.get_ticks_usec()) / 1000 + ctx.co_ticks.debug_time_offset_ms


static func clock_get_tick_timestamp_ms(ctx: WyncCtx, ticks: int) -> float:
	var frame = 1000.0 / Engine.physics_ticks_per_second
	return ctx.co_predict_data.current_tick_timestamp + (ticks - ctx.co_ticks.ticks) * frame


static func wync_get_ticks(ctx: WyncCtx):
	return ctx.co_ticks.ticks
