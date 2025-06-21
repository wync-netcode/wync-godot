class_name WyncLerp


static func wync_lerp_precompute (ctx: WyncCtx):
	var co_predict_data = ctx.co_predict_data

	var latency_info: WyncCtx.PeerLatencyInfo = ctx.peer_latency_info[WyncCtx.SERVER_PEER_ID]
	ctx.co_predict_data.lerp_latency_ms = latency_info.latency_stable_ms
	var curr_time = WyncClock.clock_get_tick_timestamp_ms(ctx, ctx.co_ticks.ticks)
	var target_time_conf = curr_time - co_predict_data.lerp_ms - ctx.co_predict_data.lerp_latency_ms

	# precompute which ticks we'll be interpolating
	# TODO: might want to use another filtered prop list for 'predicted'.
	# Before doing that we might need to settled on our strategy for extrapolation as fallback
	# of interpolation for confirmed states

	for prop_id in ctx.type_state__interpolated_regular_prop_ids:

		# -> for predictes states

		if WyncXtrap.prop_is_predicted(ctx, prop_id):
			precompute_lerping_prop_predicted(ctx, prop_id)

		# -> for confirmed states
		else:
			precompute_lerping_prop_confirmed_states(ctx, prop_id, target_time_conf)


static func precompute_lerping_prop_confirmed_states(
		ctx: WyncCtx, prop_id: int, target_time: int
	):
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	var snaps = WyncLerp.find_closest_two_snapshots_from_prop(ctx, target_time, prop)
	if snaps[0] == -1:
		return

	if (prop.lerp_left_confirmed_state_tick == snaps[0] &&
		prop.lerp_right_confirmed_state_tick == snaps[1]):
		return

	prop.lerp_use_confirmed_state = true
	prop.lerp_left_confirmed_state_tick = snaps[0]
	prop.lerp_right_confirmed_state_tick = snaps[1]
	prop.lerp_left_local_tick = snaps[2]
	prop.lerp_right_local_tick = snaps[3]

	# TODO: Move this elsewhere
	# NOTE: might want to limit how much it grows
	ctx.co_ticks.last_tick_rendered_left = max(ctx.co_ticks.last_tick_rendered_left, prop.lerp_left_confirmed_state_tick)

	var val_left = WyncEntityProp.saved_state_get_throughout(prop, prop.lerp_left_confirmed_state_tick)
	var val_right = WyncEntityProp.saved_state_get_throughout(prop, prop.lerp_right_confirmed_state_tick)

	prop.lerp_left_state = val_left
	prop.lerp_right_state = val_right



static func precompute_lerping_prop_predicted(
		ctx: WyncCtx, prop_id: int
	):
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	prop.lerp_use_confirmed_state = false
	prop.lerp_left_local_tick = ctx.co_ticks.ticks
	prop.lerp_right_local_tick = ctx.co_ticks.ticks +1


static func wync_client_set_lerp_ms (ctx: WyncCtx, server_tick_rate: float, lerp_ms: int):
	#var physics_fps: int = ctx.physic_ticks_per_second
	#var server_update_rate: int = ceil((1.0 / (ctx.server_tick_rate + 1)) * physics_fps)
	#ctx.lerp_ms = max(lerp_ms, (1000 / server_update_rate) * 2)

	ctx.co_predict_data.lerp_ms = max(lerp_ms, ceil((1000.0 / server_tick_rate) * 2))
	# TODO: also set maximum based on tick history size
	# NOTE: what about tick differences between server and clients?

## How much the lerping is allowed to extrapolate when missing packages
static func wync_client_set_max_lerp_factor_symmetric (ctx: WyncCtx, max_lerp_factor_symmetric: float):
	ctx.max_lerp_factor_symmetric = max_lerp_factor_symmetric


static func wync_handle_packet_client_set_lerp_ms(ctx: WyncCtx, data: Variant, from_nete_peer_id: int) -> int:

	if data is not WyncPktClientSetLerpMS:
		return 1
	data = data as WyncPktClientSetLerpMS

	# client and prop exists
	var client_id = WyncJoin.is_peer_registered(ctx, from_nete_peer_id)
	if client_id < 0:
		Log.err("client %s is not registered" % client_id, Log.TAG_INPUT_RECEIVE)
		return 2

	var client_info := ctx.client_has_info[client_id] as WyncClientInfo
	client_info.lerp_ms = data.lerp_ms

	return OK


static func prop_set_interpolate(ctx: WyncCtx, prop_id: int, user_data_type: int) -> int:
	if not ctx.is_client:
		return OK
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.user_data_type = user_data_type
	prop.interpolated = true
	return OK
	

static func prop_is_interpolated(ctx: WyncCtx, prop_id: int) -> bool:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return false
	return prop.interpolated


## NOTE: Here we asume `prop.last_ticks_received` is sorted
## @returns tuple[int, int, int, int]. server tick left, server tick right, local tick left, local tick right
static func find_closest_two_snapshots_from_prop(ctx: WyncCtx, target_time_ms: int, prop: WyncEntityProp) -> Array:
	
	## Note: Maybe we don't need local ticks here
	var done_selecting_right = false
	var rhs_tick_server = -1
	var rhs_tick_server_prev = -1
	var rhs_tick_local = -1
	var rhs_tick_local_prev = -1
	var lhs_tick_server = -1
	var lhs_tick_local = -1
	var lhs_timestamp = 0
	var size = prop.last_ticks_received.size

	var server_tick = 0
	var server_tick_prev = 0

	for i in range(size):
		server_tick_prev = server_tick
		server_tick = prop.last_ticks_received.get_absolute(size -1 -i)

		if server_tick == -1:
			if (lhs_tick_server == -1 or
	   			lhs_tick_server >= rhs_tick_server) and rhs_tick_server_prev != -1:

				lhs_tick_server = rhs_tick_server
				lhs_tick_local = rhs_tick_local
				rhs_tick_server = rhs_tick_server_prev
				rhs_tick_local = rhs_tick_local_prev
			else:
				continue
		elif server_tick == server_tick_prev:
			continue


		# This check is necessary because of the current strategy
		# where we sort last_ticks_received causing newer received ticks (albeit older
		# numerically) to overlive older received ticks with higher number
		var data = WyncEntityProp.saved_state_get_throughout(prop, server_tick)
		if data == null:
			continue

		# calculate local tick from server tick
		var local_tick = server_tick - ctx.co_ticks.server_tick_offset
		var snapshot_timestamp = WyncClock.clock_get_tick_timestamp_ms(ctx, local_tick)

		if not done_selecting_right:

			if snapshot_timestamp > target_time_ms:

				rhs_tick_server_prev = rhs_tick_server
				rhs_tick_local_prev = rhs_tick_local
				rhs_tick_server = server_tick
				rhs_tick_local = local_tick

			else:
				done_selecting_right = true
				if rhs_tick_server == -1:
					rhs_tick_server = server_tick

		if (snapshot_timestamp > lhs_timestamp or
			lhs_tick_server == -1 or
	  		lhs_tick_server >= rhs_tick_server
		):
			lhs_tick_server = server_tick
			lhs_tick_local = local_tick
			lhs_timestamp = snapshot_timestamp
			# TODO: End prematurely when both sides are found

	if (lhs_tick_server == -1 or
		lhs_tick_server >= rhs_tick_server) and rhs_tick_server_prev != -1:

		lhs_tick_server = rhs_tick_server
		lhs_tick_local = rhs_tick_local
		rhs_tick_server = rhs_tick_server_prev
		rhs_tick_local = rhs_tick_local_prev
	
	if lhs_tick_server == -1 || rhs_tick_server == -1:
		return [-1, 0, 0, 0]
	
	return [lhs_tick_server, rhs_tick_server, lhs_tick_local, rhs_tick_local]
