class_name WyncXtrap

## functions to preform extrapolation / prediction


static func wync_xtrap_preparation(ctx: WyncCtx) -> int:
	if ctx.last_tick_received == 0:
		return 1
	ctx.currently_on_predicted_tick = true
	ctx.xtrap_is_local_tick_duplicated = false
	ctx.xtrap_prev_local_tick = null # Optional<int>
	ctx.xtrap_local_tick = null # Optional<int>
	ctx.first_tick_predicted = ctx.last_tick_received +1
	ctx.pred_intented_first_tick = ctx.last_tick_received +1

	return OK


static func wync_xtrap_tick_init_cache(ctx: WyncCtx):
	ctx.present_input_prop_ids.clear()
	ctx.present_delta_prop_ids.clear()
	ctx.present_pred_auxiliar_prop_ids.clear()
	
	# --------------------------------------------------
	# ALL INPUT/EVENT PROPS, no excepcion for now
	# TODO: identify which I own and which belong to my foes'

	# set events inputs to corresponding value depending on tick
	# TODO: could this be generalized with 'wync_input_props_set_tick_value' ?
	
	for prop_id: int in ctx.active_prop_ids:
		var prop := WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		var predicted = WyncUtils.prop_is_predicted(ctx, prop_id)
		var is_input = prop.data_type in [WyncEntityProp.DATA_TYPE.INPUT, WyncEntityProp.DATA_TYPE.EVENT]

		if predicted && is_input:
			ctx.present_input_prop_ids.append(prop_id)

		if prop.relative_syncable:
			var aux_prop := WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
			if aux_prop != null:
				ctx.present_delta_prop_ids.append(prop_id)

				if predicted:
					ctx.present_pred_auxiliar_prop_ids.append(prop.auxiliar_delta_events_prop_id)


static func auxiliar_props_clear_current_delta_events_cache(ctx: WyncCtx):
	ctx.present_delta_prop_ids.clear()
	for prop_id: int in ctx.active_prop_ids:
		var prop := WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if not prop.relative_syncable:
			continue
		var aux_prop := WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			continue
		ctx.present_delta_prop_ids.append(prop_id)


static func wync_xtrap_tick_end_cache(ctx: WyncCtx):
	ctx.present_to_integrate_pred_entity_ids.clear()

	for wync_entity_id: int in ctx.tracked_entities.keys():
	
		if !WyncUtils.entity_is_predicted(ctx, wync_entity_id):
			continue
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, wync_entity_id)
		if typeof(int_fun) != TYPE_CALLABLE:
			continue

		ctx.present_to_integrate_pred_entity_ids.append(wync_entity_id)


	#ctx.present_pred_delta_prop_ids.clear()
	#for prop_id: int in ctx.active_prop_ids:
		#var prop := WyncUtils.get_prop(ctx, prop_id)
		#if prop == null:
			#continue
		#if not prop.relative_syncable:
			#continue
		#if not WyncUtils.prop_is_predicted(ctx, prop_id):
			#continue
		#var aux_prop := WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		#if aux_prop == null:
			#assert(false)
			#continue
		#ctx.present_pred_delta_prop_ids.append(prop_id)


static func wync_xtrap_tick_init(ctx: WyncCtx, tick: int):
	for prop_id: int in ctx.active_prop_ids:
		var prop := ctx.props[prop_id]
		if prop.confirmed_states_tick.get_at(tick) != tick:
			continue
		prop.setter.call(prop.user_ctx_pointer, prop.confirmed_states.get_at(tick))

	ctx.current_predicted_tick = tick

	# clearing delta events before predicting, predicted delta events will be
	# polled and cached at the end of the predicted tick
	WyncXtrap.auxiliar_props_clear_current_delta_events(ctx)


static func auxiliar_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id: int in ctx.present_delta_prop_ids:
		var prop := ctx.props[prop_id]
		var aux_prop = ctx.props[prop.auxiliar_delta_events_prop_id]
		prop.current_delta_events.clear()
		aux_prop.current_undo_delta_events.clear()


# which entities shouldnt' be predicted in this tick:
# * entities containing delta props
# * entities with an already confirmed state for this tick
# These props need their state reset to that tick
# * props that are predicted and already have a confirmed state for this tick
static func wync_xtrap_dont_predict_entities(ctx: WyncCtx, tick: int) -> Array[int]:
	var entity_ids := [] as Array[int]

	var pred_start_tick = ctx.last_tick_received +1
	if tick >= pred_start_tick:
		return []

	# iterate each entity and determine if they shouldn't be predicted
	for entity_id in ctx.tracked_entities.keys():
		var entity_last_tick = WyncUtils.entity_get_last_received_tick(ctx, entity_id)

		# contains a delta prop
		if WyncUtils.entity_has_delta_prop(ctx, entity_id):
			entity_ids.append(entity_id)
		
		# no history
		elif entity_last_tick == -1:
			entity_ids.append(entity_id)

		# WARNING: Do not assume that we have all -10 past tick just before 'entity_last_tick'

		# already have confirmed state + it's regular prop
		elif entity_last_tick >= tick:
			entity_ids.append(entity_id)

	return entity_ids


static func wync_xtrap_tick_end(ctx: WyncCtx, tick: int):

	var store_predicted_states = tick > (ctx.co_predict_data.target_tick - 1)

	# wync bookkeeping
	# --------------------------------------------------

	for wync_entity_id: int in ctx.present_to_integrate_pred_entity_ids:
		# (run on last two iterations)
		if store_predicted_states:
			# store predicted states
			WyncXtrap.props_update_predicted_states_data(ctx, ctx.entity_has_props[wync_entity_id])

			# update/store predicted state metadata
			WyncXtrap.props_update_predicted_states_ticks(ctx, ctx.entity_has_props[wync_entity_id], ctx.co_predict_data.target_tick)

		# integration functions
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, wync_entity_id)
		int_fun.call()


	# extract / poll for generated predicted _undo delta events_

	if tick >= ctx.pred_intented_first_tick:
		for prop_id: int in ctx.present_pred_auxiliar_prop_ids:
			#var prop := ctx.props[prop_id]
			var aux_prop := ctx.props[prop_id]
			
			var undo_events = aux_prop.current_undo_delta_events.duplicate(true)
			aux_prop.confirmed_states_undo.insert_at(tick, undo_events)
			aux_prop.confirmed_states_undo_tick.insert_at(tick, tick)

	ctx.last_tick_predicted = tick


static func wync_xtrap_termination(ctx: WyncCtx):
	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)
	ctx.currently_on_predicted_tick = false


static func props_update_predicted_states_data(ctx: WyncCtx, props_ids: Array) -> void:
	
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
		
		pred_prev.data = pred_curr.data
		pred_curr.data = prop.getter.call(prop.user_ctx_pointer)


static func props_update_predicted_states_ticks(ctx: WyncCtx, props_ids: Array, target_tick: int) -> void:
	
	for prop_id: int in props_ids:
		
		var prop := ctx.props[prop_id]
		if prop == null:
			continue
		if not WyncUtils.prop_is_predicted(ctx, prop_id):
			continue

		# update store predicted state metadata
		
		prop.pred_prev.server_tick = target_tick -1
		prop.pred_curr.server_tick = target_tick
