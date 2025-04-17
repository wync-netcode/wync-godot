class_name WyncWrapper


## User facing functions, these must not be used elsewhere by the library


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


static func wync_buffer_inputs(ctx: WyncCtx):
	
	if not ctx.connected:
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in ctx.type_input_event__owned_prop_ids:

		var input_prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		var new_state = getter.call(user_ctx)
		assert(new_state != null)

		input_prop.confirmed_states.insert_at(ctx.co_predict_data.target_tick, new_state)
		input_prop.confirmed_states_tick.insert_at(ctx.co_predict_data.target_tick, ctx.co_predict_data.target_tick)


static func extract_data_to_tick(ctx: WyncCtx, save_on_tick: int = -1):

	# Save state history per tick

	for prop_id in ctx.filtered_regular_extractable_prop_ids:
		
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		prop.confirmed_states.insert_at(save_on_tick, getter.call(user_ctx))
		prop.confirmed_states_tick.insert_at(save_on_tick, save_on_tick)

	for prop_id in ctx.filtered_delta_prop_ids:
		
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		var prop_aux := WyncUtils.get_prop_unsafe(ctx, prop.auxiliar_delta_events_prop_id)
		prop_id = prop.auxiliar_delta_events_prop_id
		prop = prop_aux
		
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		prop.confirmed_states.insert_at(save_on_tick, getter.call(user_ctx))
		prop.confirmed_states_tick.insert_at(save_on_tick, save_on_tick)


static func reset_all_state_to_confirmed_tick_relative(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick)
		if last_confirmed_tick == -1:
			continue
		if prop.confirmed_states_tick.get_at(last_confirmed_tick) != last_confirmed_tick:
			continue
		var last_confirmed = prop.confirmed_states.get_at(last_confirmed_tick as int)
		if last_confirmed == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, last_confirmed)
		if prop_id == 6:
			Log.outc(ctx, "debugging set latest state prop_id %s to tick %s" % [prop_id, last_confirmed_tick])


static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for prop_id in ctx.filtered_clients_input_and_event_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)	

		if prop.confirmed_states_tick.get_at(ctx.co_ticks.ticks) != ctx.co_ticks.ticks:
			Log.errc(ctx, "couldn't find input (%s) for tick (%s)" % [prop.name_id, ctx.co_ticks.ticks])
			continue

		var input = prop.confirmed_states.get_at(ctx.co_ticks.ticks)
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, input)
		#Log.outc(ctx, "(tick %s) setted input prop (%s) to %s" % [ctx.co_ticks.ticks, prop.name_id, input])

	return OK


## for inputs / events
static func xtrap_reset_all_state_to_confirmed_tick_absolute(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	for prop_id: int in prop_ids:
		var prop := ctx.props[prop_id]
		if prop.confirmed_states_tick.get_at(tick) != tick:
			continue
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, prop.confirmed_states.get_at(tick))
		#Log.outc(ctx, "tick init setted state for prop %s tick %s" % [prop.name_id, tick])


static func xtrap_props_update_predicted_states_data(ctx: WyncCtx, props_ids: Array) -> void:
	
	for prop_id: int in props_ids:
		
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop == null:
			continue

		var pred_curr = prop.pred_curr
		var pred_prev = prop.pred_prev
		
		# Initialize stored predicted states. TODO: Move elsewhere
		
		if pred_curr.data == null:
			pred_curr.data = Vector2.ZERO
			pred_prev = pred_curr.copy()
			continue
			
		# store predicted states
		# (run on last two iterations)
		
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		pred_prev.data = pred_curr.data
		pred_curr.data = getter.call(user_ctx)


## interpolates confirmed states and predicted states
static func wync_interpolate_all(ctx: WyncCtx, delta: float):

	var frame := 1000.0 / Engine.physics_ticks_per_second

	var co_predict_data = ctx.co_predict_data
	var co_ticks = ctx.co_ticks
	co_ticks.lerp_delta_accumulator_ms += delta * 1000
	var curr_tick_time = WyncUtils.clock_get_tick_timestamp_ms(ctx, co_ticks.ticks)
	var curr_time: float = curr_tick_time + co_ticks.lerp_delta_accumulator_ms
	var target_time_conf: float = curr_time - co_predict_data.lerp_ms
	var target_time_pred: float = curr_time

	curr_time = co_ticks.lerp_delta_accumulator_ms
	curr_time = Engine.get_physics_interpolation_fraction() * frame
	target_time_conf = curr_time - co_predict_data.lerp_ms
	target_time_pred = curr_time

	# then interpolate them 

	#var sel_ticks: int = co_ticks.server_ticks
	#var sel_ticks: int = co_ticks.ticks
	var left_timestamp_ms: float
	var right_timestamp_ms: float
	var left_value: Variant
	var right_value: Variant
	var factor: float

	#Log.outc(ctx, "deblerp | curr_tick_time %s delta_acc %s curr_time %s" % [
		#curr_tick_time, co_ticks.lerp_delta_accumulator_ms, curr_time
		#])

	for prop_id in ctx.type_state__interpolated_regular_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)

		# NOTE: opportunity to optimize this by not recalculating this each loop

		left_timestamp_ms = (prop.lerp_left_local_tick - co_ticks.ticks) * frame
		right_timestamp_ms = (prop.lerp_right_local_tick - co_ticks.ticks) * frame
		#left_timestamp_ms = (prop.lerp_left_confirmed_state_tick - sel_ticks) * frame
		#right_timestamp_ms = (prop.lerp_right_confirmed_state_tick - sel_ticks) * frame

		if prop.lerp_use_confirmed_state:
			left_value = prop.confirmed_states.get_at(prop.lerp_left_confirmed_state_tick)
			right_value = prop.confirmed_states.get_at(prop.lerp_right_confirmed_state_tick)
		else:
			# TODO: Come up with a better approach with less branches
			if prop.pred_prev == null:
				continue
			left_value = prop.pred_prev.data
			right_value = prop.pred_curr.data
		if left_value == null:
			continue

		var debug_previous: Vector2

		# NOTE: Maybe check for value integrity

		if abs(left_timestamp_ms - right_timestamp_ms) < 0.000001:
			prop.interpolated_state = right_value
		else:
			if prop.lerp_use_confirmed_state:
				factor = (target_time_conf - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms)
			else:
				factor = (target_time_pred - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms)

			# TODO: Make it a config toggleable option
			# TODO: Allow extrapolation up to 1000ms (configurable)
			#factor = clampf(factor, 0, 1)

			var lerp_func_id = ctx.wrapper.lerp_type_to_lerp_function[prop.user_data_type]
			var lerp_func = ctx.wrapper.lerp_function[lerp_func_id]

			if prop.interpolated_state != null: debug_previous = prop.interpolated_state

			prop.interpolated_state = lerp_func.call(left_value, right_value, factor)

			#if not prop.lerp_use_confirmed_state:
		if prop_id == 18:

			var txt = "deblerp | p_id%s | l(%s) r(%s) | l(%.2f) r(%.2f) | left %.2f right %.2f target %.3f d %.3f | delta %.3f acu %.3f factor %.3f lerp_fra %.3f | curr %.3f d %2.3f | pos %.3f diff %2.3f" % [
				prop_id,
				prop.lerp_left_local_tick, prop.lerp_right_local_tick,
				left_value.x, right_value.x,
				left_timestamp_ms, right_timestamp_ms, target_time_conf,
				target_time_conf - ctx.debug_lerp_prev_target,
				delta * 1000, co_ticks.lerp_delta_accumulator_ms, factor,
				Engine.get_physics_interpolation_fraction(),
				curr_time, curr_time - ctx.debug_lerp_prev_curr_time,
				prop.interpolated_state.x, (prop.interpolated_state.x - debug_previous.x)]
			DynamicDebugInfo.custom_global_text = txt
			Log.outc(ctx, txt)

	ctx.debug_lerp_prev_curr_time = curr_time
	ctx.debug_lerp_prev_target = target_time_conf


## Q: Is it possible that event_ids accumulate infinitely if they are never consumed?
## A: No, if events are never consumed they remain in the confirmed_states buffer until eventually replaced.
## Returns events from this tick, that aren't consumed
## TODO: Move out of wrapper
static func wync_get_events_from_channel_from_peer(
	ctx: WyncCtx, wync_peer_id: int, channel: int, tick: int
	) -> Array[int]:

	var out_events_id: Array[int] = []
	if tick < 0:
		return out_events_id

	var prop_id: int = ctx.prop_id_by_peer_by_channel[wync_peer_id][channel]
	var prop_channel := WyncUtils.get_prop_unsafe(ctx, prop_id)

	var consumed_event_ids_tick: int = prop_channel.events_consumed_at_tick_tick.get_at(tick)
	if tick != consumed_event_ids_tick:
		return out_events_id
	var confirmed_state_tick = prop_channel.confirmed_states_tick.get_at(tick)
	if tick != confirmed_state_tick:
		return out_events_id

	var consumed_event_ids: Array[int] = prop_channel.events_consumed_at_tick.get_at(tick)
	var confirmed_event_ids: Array

	if ctx.co_ticks.ticks == tick:
		confirmed_event_ids = ctx.peer_has_channel_has_events[wync_peer_id][channel]
	else:
		confirmed_event_ids = prop_channel.confirmed_states.get_at(tick)

	for i in range(confirmed_event_ids.size()):
		var event_id = confirmed_event_ids[i]
		if consumed_event_ids.has(event_id):
			continue
		if not ctx.events.has(event_id):
			continue

		var event := ctx.events[event_id]
		assert(event != null)
		out_events_id.append(event_id)

	return out_events_id
