class_name WyncXtrap

## functions to preform extrapolation / prediction


static func wync_xtrap_preparation(ctx: WyncCtx) -> int:
	if ctx.last_tick_received == 0:
		return 1
	ctx.currently_on_predicted_tick = true
	ctx.xtrap_is_local_tick_duplicated = false
	ctx.xtrap_prev_local_tick = null # Optional<int>
	ctx.xtrap_local_tick = null # Optional<int>

	if ctx.last_tick_received_prev != ctx.last_tick_received:
		ctx.last_tick_received_prev = ctx.last_tick_received
		ctx.pred_intented_first_tick = ctx.last_tick_received +1
	else:
		ctx.pred_intented_first_tick = ctx.last_tick_predicted

	ctx.first_tick_predicted = ctx.pred_intented_first_tick

	if ctx.co_predict_data.target_tick <= ctx.co_ticks.server_ticks:
		return 2
	if ctx.pred_intented_first_tick - ctx.max_prediction_tick_threeshold < 0:
		return 3

	return OK


# Note: further optimization could involve removing adding singular props from the list
static func wync_server_tick_end_cache_filtered_input_ids(ctx: WyncCtx):
	if not ctx.was_any_prop_added_deleted:
		return
	ctx.was_any_prop_added_deleted = false
	Log.outc(ctx, "debug filters")

	ctx.filtered_clients_input_and_event_prop_ids.clear()
	ctx.filtered_delta_prop_ids.clear()
	ctx.filtered_regular_extractable_prop_ids.clear()

	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
			if (prop.prop_type != WyncEntityProp.PROP_TYPE.INPUT &&
				prop.prop_type != WyncEntityProp.PROP_TYPE.EVENT):
				continue
			ctx.filtered_clients_input_and_event_prop_ids.append(prop_id)

	for prop_id in ctx.active_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		if prop.prop_type in [
			WyncEntityProp.PROP_TYPE.INPUT,
			WyncEntityProp.PROP_TYPE.EVENT
		]:
			continue
		if prop.relative_syncable:
			ctx.filtered_delta_prop_ids.append(prop_id)
			# TODO: Check if it has a healthy _auxiliar prop_
		else:
			ctx.filtered_regular_extractable_prop_ids.append(prop_id)


static func wync_client_filter_prop_ids(ctx: WyncCtx):
	if not ctx.was_any_prop_added_deleted:
		return
	ctx.was_any_prop_added_deleted = false
	Log.outc(ctx, "debug filters")

	ctx.type_input_event__owned_prop_ids.clear()
	ctx.type_input_event__predicted_owned_prop_ids.clear()
	ctx.type_event__predicted_prop_ids.clear()
	ctx.type_event__predicted_auxiliar_prop_ids.clear()
	ctx.type_state__delta_prop_ids.clear()
	ctx.type_state__predicted_delta_prop_ids.clear()
	ctx.type_state__predicted_regular_prop_ids.clear()
	ctx.type_state__interpolated_regular_prop_ids.clear()

	ctx.predicted_integrable_entity_ids.clear()
	ctx.predicted_entity_ids.clear()

	# Where are active props set?

	for prop_id in ctx.client_owns_prop[ctx.my_peer_id]:
		var prop := WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.prop_type != WyncEntityProp.PROP_TYPE.STATE:
			ctx.type_input_event__owned_prop_ids.append(prop_id)
			if WyncUtils.prop_is_predicted(ctx, prop_id):
				ctx.type_input_event__predicted_owned_prop_ids.append(prop_id)

	for prop_id in ctx.active_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		var is_predicted := WyncUtils.prop_is_predicted(ctx, prop_id)

		if prop.prop_type == WyncEntityProp.PROP_TYPE.EVENT:
			if is_predicted:
				ctx.type_event__predicted_prop_ids.append(prop_id)
				# Note: check if we don't own it?
				if prop.is_auxiliar_prop:
					ctx.type_event__predicted_auxiliar_prop_ids.append(prop_id)

		if prop.prop_type == WyncEntityProp.PROP_TYPE.STATE:
			if prop.relative_syncable:
				ctx.type_state__delta_prop_ids.append(prop_id)
				if is_predicted:
					ctx.type_state__predicted_delta_prop_ids.append(prop_id)
			else: # regular
				if is_predicted:
					ctx.type_state__predicted_regular_prop_ids.append(prop_id)
				if prop.interpolated:
					ctx.type_state__interpolated_regular_prop_ids.append(prop_id)

	for wync_entity_id: int in ctx.entity_has_integrate_fun.keys():
		if not WyncUtils.entity_is_predicted(ctx, wync_entity_id):
			continue
		ctx.predicted_integrable_entity_ids.append(wync_entity_id)

	for wync_entity_id in ctx.tracked_entities.keys():
		if not WyncUtils.entity_is_predicted(ctx, wync_entity_id):
			continue
		if WyncUtils.entity_has_delta_prop(ctx, wync_entity_id):
			continue
		ctx.predicted_entity_ids.append(wync_entity_id)


static func wync_xtrap_tick_init(ctx: WyncCtx, tick: int):
	# reset predicted inputs / events
	WyncWrapper.xtrap_reset_all_state_to_confirmed_tick_absolute(ctx, ctx.type_input_event__predicted_owned_prop_ids, tick)

	# reset predicted regular
	#WyncWrapper.xtrap_reset_all_state_to_confirmed_tick_absolute(ctx, ctx.type_state__predicted_regular_prop_ids, tick)

	ctx.current_predicted_tick = tick

	# clearing delta events before predicting, predicted delta events will be
	# polled and cached at the end of the predicted tick
	WyncXtrap.auxiliar_props_clear_current_delta_events(ctx)


static func auxiliar_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id: int in ctx.type_state__delta_prop_ids:
		var prop := ctx.props[prop_id]
		var aux_prop = ctx.props[prop.auxiliar_delta_events_prop_id]
		prop.current_delta_events.clear()
		aux_prop.current_undo_delta_events.clear()


# which entities shouldnt' be predicted in this tick:
# * entities containing delta props
# * entities with an already confirmed state for this tick or a higher tick
# * entities that haven't received new state
# These props need their state reset to that tick. Why here this ???
# * props that are predicted and already have a confirmed state for this tick
static func wync_xtrap_dont_predict_entities(ctx: WyncCtx, tick: int) -> Array[int]:
	var entity_ids := [] as Array[int]

	var entity_last_tick: int
	var entity_last_predicted_tick: int

	# iterate each entity and determine if they shouldn't be predicted
	for entity_id in ctx.predicted_entity_ids:

		entity_last_tick = ctx.entity_last_received_tick[entity_id]
		
		# no history
		if entity_last_tick == -1:
			continue

		# WARNING: Do not assume that we have all -10 past tick just before 'entity_last_tick'

		# already have confirmed state + it's regular prop
		elif entity_last_tick >= tick:
			continue

		entity_last_predicted_tick = ctx.entity_last_predicted_tick[entity_id]

		if tick <= entity_last_predicted_tick:
			continue

		# else, assume this entity will be predicted
		# Note: Maybe the user could report this
		if tick > entity_last_predicted_tick:
			ctx.entity_last_predicted_tick[entity_id] = tick

		entity_ids.append(entity_id)


	return entity_ids


static func wync_xtrap_tick_end(ctx: WyncCtx, tick: int):

	# wync bookkeeping
	# --------------------------------------------------

	# (run on last two iterations)

	var store_predicted_states = tick > (ctx.co_predict_data.target_tick - 1)
	if store_predicted_states:
		for wync_entity_id: int in ctx.predicted_entity_ids:
			# TODO: Make this call user-level
			# store predicted states
			WyncWrapper.xtrap_props_update_predicted_states_data(ctx, ctx.entity_has_props[wync_entity_id])

			# update/store predicted state metadata
			WyncXtrap.props_update_predicted_states_ticks(ctx, ctx.entity_has_props[wync_entity_id], ctx.co_predict_data.target_tick)

	# integration functions

	for wync_entity_id: int in ctx.predicted_integrable_entity_ids:
		# TODO: Move this to user level wrapper
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, wync_entity_id)
		int_fun.call()

	# extract / poll for generated predicted _undo delta events_

	if tick >= ctx.pred_intented_first_tick:
		for prop_id: int in ctx.type_event__predicted_auxiliar_prop_ids:
			var aux_prop := ctx.props[prop_id]
			
			var undo_events = aux_prop.current_undo_delta_events.duplicate(true)
			aux_prop.confirmed_states_undo.insert_at(tick, undo_events)
			aux_prop.confirmed_states_undo_tick.insert_at(tick, tick)

	ctx.last_tick_predicted = tick


static func wync_xtrap_termination(ctx: WyncCtx):
	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)
	WyncDeltaSyncUtils.predicted_props_clear_events(ctx)
	ctx.currently_on_predicted_tick = false


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
