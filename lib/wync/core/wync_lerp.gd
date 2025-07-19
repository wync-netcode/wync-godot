class_name WyncLerp


# ==================================================
# Public API
# ==================================================


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
		Log.errc(ctx, "client %s is not registered" % client_id)
		return 2

	var client_info := ctx.client_has_info[client_id] as WyncCtx.WyncClientInfo
	client_info.lerp_ms = data.lerp_ms

	return OK


static func prop_set_interpolate(ctx: WyncCtx, prop_id: int, user_data_type: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	assert(user_data_type > 0) # avoid accidental default values
	prop.user_data_type = user_data_type

	# * the server needs to know for subtick timewarping
	# * client needs to know for visual lerping
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


# ==================================================
# WRAPPER
# ==================================================


static func wync_register_lerp_type (ctx: WyncCtx, user_type_id: int, lerp_fun: Callable):
	if user_type_id < 0 || user_type_id >= WyncWrapperStructs.WRAPPER_MAX_USER_TYPES:
		assert(false)
	ctx.wrapper.lerp_type_to_lerp_function[user_type_id] = ctx.wrapper.lerp_function.size()
	ctx.wrapper.lerp_function.append(lerp_fun)


## interpolates confirmed states and predicted states
## @argument delta_lerp_fraction float. Usually but not always in range 0 to 1. Fraction through the current physics tick we are at the time of rendering the frame.
static func wync_interpolate_all(ctx: WyncCtx, delta_lerp_fraction: float):

	var frame := 1000.0 / Engine.physics_ticks_per_second

	# TODO: Replace "Engine.get_physics_interpolation_fraction" with user arg
	var delta_fraction_ms: float = delta_lerp_fraction * frame
	# Note: substracting one frame to compensate for one frame added by delta_fraction_ms
	var target_time_conf: float = delta_fraction_ms - frame - ctx.co_predict_data.lerp_ms - ctx.co_predict_data.lerp_latency_ms
	var target_time_pred: float = delta_fraction_ms

	# time between last rendered tick and current frame target
	var last_tick_rendered_left_timestamp = frame * (
		ctx.co_ticks.last_tick_rendered_left - ctx.co_ticks.server_tick_offset - ctx.co_ticks.ticks)
	ctx.co_ticks.minimum_lerp_fraction_accumulated_ms = target_time_conf - last_tick_rendered_left_timestamp

	# NOTE, Expanded equation: frame * (ctx.co_ticks.server_tick_offset + ctx.co_ticks.ticks + delta_lerp_fraction - ctx.co_ticks.last_tick_rendered_left -1) - ctx.co_predict_data.lerp_ms - ctx.co_predict_data.lerp_latency_ms

	var left_timestamp_ms: float
	var right_timestamp_ms: float
	var left_value: Variant
	var right_value: Variant
	var factor: float

	for prop_id in ctx.type_state__interpolated_regular_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		if prop.lerp_use_confirmed_state:
			left_value = prop.lerp_left_state
			right_value = prop.lerp_right_state

			## Note: getting time by ticks strictly

			left_timestamp_ms = (prop.lerp_left_confirmed_state_tick
			- ctx.co_ticks.server_tick_offset - ctx.co_ticks.ticks) * frame
			right_timestamp_ms = (prop.lerp_right_confirmed_state_tick
			- ctx.co_ticks.server_tick_offset - ctx.co_ticks.ticks) * frame

		else:

			# MAYBEDO: Come up with a better approach with less branches
			# Maybe mark it for no lerp on precompute
			if prop.pred_prev == null:
				continue

			left_value = prop.pred_prev.data
			right_value = prop.pred_curr.data

			# MAYBEDO: opportunity to optimize this by not recalculating this each loop (prediction only)

			left_timestamp_ms = (prop.lerp_left_local_tick - ctx.co_ticks.ticks) * frame
			right_timestamp_ms = (prop.lerp_right_local_tick - ctx.co_ticks.ticks) * frame

		if left_value == null:
			continue

		# MAYBEDO: Maybe check for value integrity

		if abs(left_timestamp_ms - right_timestamp_ms) < 0.000001:
			prop.interpolated_state = right_value
		else:
			if prop.lerp_use_confirmed_state:
				factor = (target_time_conf - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms)
			else:
				factor = (target_time_pred - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms)
			if (factor < (0 - ctx.max_lerp_factor_symmetric) ||
				factor > (1 + ctx.max_lerp_factor_symmetric)):
				continue

			var lerp_func_id = ctx.wrapper.lerp_type_to_lerp_function[prop.user_data_type]
			var lerp_func = ctx.wrapper.lerp_function[lerp_func_id]

			prop.interpolated_state = lerp_func.call(left_value, right_value, factor)

	ctx.debug_lerp_prev_curr_time = delta_fraction_ms
	ctx.debug_lerp_prev_target = target_time_conf


## timewarp, server only
## @argument tick_left: int. Base tick to restore state from
static func wync_reset_state_to_interpolated_absolute (
	ctx: WyncCtx,
	prop_ids: Array[int],
	tick_left: int,
	lerp_delta_ms: float,
	):

	var frame = 1000.0 / ctx.physic_ticks_per_second

	# then interpolate them

	var left_value: Variant
	var right_value: Variant

	for prop_id: int in prop_ids:

		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue

		left_value = WyncEntityProp.saved_state_get(prop, tick_left)
		right_value = WyncEntityProp.saved_state_get(prop, tick_left +1)
		if left_value == null || right_value == null:
			Log.errc(ctx, "debugtimewarp, (tick %s) NOT FOUND one of: left %s right %s" % [tick_left, left_value, right_value])
			continue

		# TODO: wrap this into a function
		var lerp_func_id = ctx.wrapper.lerp_type_to_lerp_function[prop.user_data_type]
		var lerp_func: Callable = ctx.wrapper.lerp_function[lerp_func_id]
		var lerped_state = lerp_func.call(left_value, right_value, lerp_delta_ms/frame)

		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, lerped_state)

		#Log.outc(ctx, "debugtimewarpevent, left %s right %s lerped %s delta %s (%s) --- prop_id %s name %s" % [left_value, right_value, lerped_state, lerp_delta_ms, lerp_delta_ms/frame, prop_id, prop.name_id])

