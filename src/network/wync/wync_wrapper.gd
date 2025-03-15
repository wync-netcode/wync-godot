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
	
	for prop_id: int in ctx.client_owns_prop[ctx.my_peer_id]:
		
		# Log.out(node_self, "client owns prop %s" % prop_id)
		if not WyncUtils.prop_exists(ctx, prop_id):
			Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var input_prop := WyncUtils.get_prop(ctx, prop_id)
		if input_prop == null:
			Log.err("not input_prop %s" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		if input_prop.prop_type not in [
			WyncEntityProp.PROP_TYPE.INPUT,
			WyncEntityProp.PROP_TYPE.EVENT]:
			Log.err("prop %s is not INPUT or EVENT" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
	
		# Log.out(node_self, "gonna call getter for prop %s" % prop_id)
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		var new_state = getter.call(user_ctx)
		if new_state == null:
			Log.out("new_state == null :%s" % [new_state], Log.TAG_INPUT_BUFFER)
			assert(false)
			continue

		input_prop.confirmed_states.insert_at(ctx.co_predict_data.target_tick, new_state)
		input_prop.confirmed_states_tick.insert_at(ctx.co_predict_data.target_tick, ctx.co_predict_data.target_tick)


static func extract_data_to_tick(ctx: WyncCtx, save_on_tick: int = -1):
	
	for entity_id_key in ctx.entity_has_props.keys():

		var prop_ids_array = ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		for prop_id in prop_ids_array:
			
			var prop := WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			
			# don't extract input values
			# FIXME: should events be extracted? game event yes, but other player events? Maybe we need an option to what events to share.
			# NOTE: what about a setting like: NEVER, TO_ALL, TO_ALL_EXCEPT_OWNER, ONLY_TO_SERVER
			if prop.prop_type in [WyncEntityProp.PROP_TYPE.INPUT,
				WyncEntityProp.PROP_TYPE.EVENT]:
				continue

			# relative_syncable receives special treatment

			if prop.relative_syncable:
				
				# Allow auxiliar props
				#prop_id = prop.auxiliar_delta_events_prop_id
				var prop_aux = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
				if prop_aux == null:
					continue
				prop = prop_aux
			
			# ===========================================================
			# Save state history per tick
			
			#if prop_id != 14:
				#continue
			var getter = ctx.wrapper.prop_getter[prop_id]
			var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
			prop.confirmed_states.insert_at(save_on_tick, getter.call(user_ctx))
			prop.confirmed_states_tick.insert_at(save_on_tick, save_on_tick)


static func reset_all_state_to_confirmed_tick_relative(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue 
		prop = prop as WyncEntityProp
		
		
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
		
	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			if not WyncUtils.prop_exists(ctx, prop_id):
				continue
			var prop := WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			if (prop.prop_type != WyncEntityProp.PROP_TYPE.INPUT &&
				prop.prop_type != WyncEntityProp.PROP_TYPE.EVENT):
				continue
		
			if prop.confirmed_states_tick.get_at(ctx.co_ticks.ticks) != ctx.co_ticks.ticks:
				Log.errc(ctx, "couldn't find input (%s) for tick (%s)" % [prop.name_id, ctx.co_ticks.ticks])
				continue

			var input = prop.confirmed_states.get_at(ctx.co_ticks.ticks)
			if input == null:
				continue

			var setter = ctx.wrapper.prop_setter[prop_id]
			var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
			setter.call(user_ctx, input)
			#Log.outc(ctx, "(tick %s) setted input prop (%s) to %s" % [ctx.co_ticks.ticks, prop.name_id, input])

	return OK


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
