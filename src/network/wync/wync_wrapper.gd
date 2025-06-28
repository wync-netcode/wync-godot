class_name WyncWrapper


## User facing functions, these must not be used elsewhere by the library

## FIXME
static func wync_set_prop_callbacks \
	(ctx: WyncCtx, prop_id: int, user_ctx: Variant, getter: Callable, setter: Callable):
	ctx.wrapper.prop_user_ctx[prop_id] = user_ctx
	ctx.wrapper.prop_getter[prop_id] = getter
	ctx.wrapper.prop_setter[prop_id] = setter


static func wync_register_lerp_type (ctx: WyncCtx, user_type_id: int, lerp_fun: Callable):
	if user_type_id < 0 || user_type_id >= WyncCtx.WRAPPER_MAX_USER_TYPES:
		assert(false)
	ctx.wrapper.lerp_type_to_lerp_function[user_type_id] = ctx.wrapper.lerp_function.size()
	ctx.wrapper.lerp_function.append(lerp_fun)


## Systems


# TODO: wync_flow
static func wync_buffer_inputs(ctx: WyncCtx):
	
	if not ctx.connected:
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in ctx.type_input_event__owned_prop_ids:

		var input_prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		var new_state = getter.call(user_ctx)
		assert(new_state != null)

		WyncEntityProp.saved_state_insert(ctx, input_prop, ctx.co_predict_data.target_tick, new_state)


# TODO: wync_flow
static func extract_data_to_tick(ctx: WyncCtx, save_on_tick: int = -1):

	var prop: WyncEntityProp = null
	var prop_aux: WyncEntityProp = null
	var getter: Variant = null # Callable*
	var user_ctx: Variant = null

	# Save state history per tick

	for prop_id in ctx.filtered_regular_extractable_prop_ids:
		prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		getter = ctx.wrapper.prop_getter[prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		
		WyncEntityProp.saved_state_insert(ctx, prop, save_on_tick, getter.call(user_ctx))
		# Note: safe to call user getter like that?

	# extracts events ids from auxiliar delta props

	for prop_id in ctx.filtered_delta_prop_ids:
		
		prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		prop_aux = WyncTrack.get_prop_unsafe(ctx, prop.auxiliar_delta_events_prop_id)
		
		getter = ctx.wrapper.prop_getter[prop.auxiliar_delta_events_prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop.auxiliar_delta_events_prop_id]
		WyncEntityProp.saved_state_insert(ctx, prop_aux, save_on_tick, getter.call(user_ctx))


# FIXME: Move calling function to wrapper (or mark it as wrapper, or to wync_state_set_wrapper.gd)
static func reset_all_state_to_confirmed_tick_relative(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick)
		if last_confirmed_tick == -1:
			continue

		var last_confirmed = WyncEntityProp.saved_state_get(prop, last_confirmed_tick as int)
		if last_confirmed == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, last_confirmed)


# TODO: wync_flow
static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for prop_id in ctx.filtered_clients_input_and_event_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)	

		var input = WyncEntityProp.saved_state_get(prop, ctx.co_ticks.ticks)
		if input == null:
			Log.errc(ctx, "couldn't find input (%s) for tick (%s)" % [prop.name_id, ctx.co_ticks.ticks])
			continue

		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, input)

	return OK




# FIXME: mark wync_xtrap_tick_end for wrapper


## interpolates confirmed states and predicted states
## @argument delta_lerp_fraction float. Usually but not always in range 0 to 1. Fraction through the current physics tick we are at the time of rendering the frame.
static func wync_interpolate_all(ctx: WyncCtx, delta_lerp_fraction: float):

	var frame := 1000.0 / Engine.physics_ticks_per_second

	# TODO: Replace "Engine.get_physics_interpolation_fraction" with user arg
	var delta_fraction_ms: float = delta_lerp_fraction * frame
	# Note: substracting one frame to compensate for one frame added by delta_fraction_ms
	var target_time_conf: float = delta_fraction_ms - frame - ctx.co_predict_data.lerp_ms - ctx.co_predict_data.lerp_latency_ms
	var target_time_pred: float = delta_fraction_ms

	var left_timestamp_ms: float
	var right_timestamp_ms: float
	var left_value: Variant
	var right_value: Variant
	var factor: float

	#Log.outc(ctx, "deblerp | curr_tick_time %s delta_acc %s delta_fraction_ms %s" % [
		#curr_tick_time, co_ticks.lerp_delta_accumulator_ms, delta_fraction_ms
		#])

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

		#var debug_previous: Vector2

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

			#if prop.interpolated_state != null: debug_previous = prop.interpolated_state

			prop.interpolated_state = lerp_func.call(left_value, right_value, factor)

		#if prop_id == 18:

			#var txt = "deblerp | p_id%s | l(%s,%s) s(%s,%s) | l(%.2f) r(%.2f) | left %.2f right %.2f target %.3f d %.3f | delta %.3f acu %.3f factor %.3f lerp_fra %.3f | curr %.3f d %2.3f | pos %.3f diff %2.3f" % [
				#prop_id,
				#prop.lerp_left_local_tick, prop.lerp_right_local_tick,
				#prop.lerp_left_confirmed_state_tick, prop.lerp_right_confirmed_state_tick,
				#left_value.x, right_value.x,
				#left_timestamp_ms, right_timestamp_ms, target_time_conf,
				#target_time_conf - ctx.debug_lerp_prev_target,
				#delta * 1000, co_ticks.lerp_delta_accumulator_ms, factor,
				#Engine.get_physics_interpolation_fraction(),
				#delta_fraction_ms, delta_fraction_ms - ctx.debug_lerp_prev_curr_time,
				#prop.interpolated_state.x, (prop.interpolated_state.x - debug_previous.x)]
			#DynamicDebugInfo.custom_global_text = txt
			#Log.outc(ctx, txt)

			# Debug only
			#var val_diff = right_value.x - left_value.x
			#if val_diff < 0 && val_diff > -100:
			#	assert(false)

	ctx.debug_lerp_prev_curr_time = delta_fraction_ms
	ctx.debug_lerp_prev_target = target_time_conf


