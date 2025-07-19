class_name WyncXtrapInternal
## wync_xtrap_internal.h


# Note: further optimization could involve removing adding singular props from the list
# TODO: rename, server doesn't do any xtrap related
static func wync_xtrap_server_filter_prop_ids(ctx: WyncCtx):
	if not ctx.was_any_prop_added_deleted:
		return
	ctx.was_any_prop_added_deleted = false
	Log.outc(ctx, "debug filters")

	ctx.filtered_clients_input_and_event_prop_ids.clear()
	ctx.filtered_delta_prop_ids.clear()
	ctx.filtered_regular_extractable_prop_ids.clear()
	ctx.filtered_regular_timewarpable_prop_ids.clear()

	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
			if (prop.prop_type != WyncEntityProp.PROP_TYPE.INPUT &&
				prop.prop_type != WyncEntityProp.PROP_TYPE.EVENT):
				continue
			ctx.filtered_clients_input_and_event_prop_ids.append(prop_id)

	for prop_id in ctx.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		if (prop.prop_type != WyncEntityProp.PROP_TYPE.STATE &&
			prop.prop_type != WyncEntityProp.PROP_TYPE.INPUT):
			continue

		if (prop.relative_syncable &&
			prop.prop_type == WyncEntityProp.PROP_TYPE.STATE):
			ctx.filtered_delta_prop_ids.append(prop_id)
			# TODO: Check if it has a healthy _auxiliar prop_

		else:
			if (prop.prop_type == WyncEntityProp.PROP_TYPE.STATE):
				ctx.filtered_regular_extractable_prop_ids.append(prop_id)

			if prop.timewarpable:
				ctx.filtered_regular_timewarpable_prop_ids.append(prop_id)
				if prop.interpolated:
					ctx.filtered_regular_timewarpable_interpolable_prop_ids.append(prop_id)


static func wync_xtrap_client_filter_prop_ids(ctx: WyncCtx):
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
		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.prop_type != WyncEntityProp.PROP_TYPE.STATE:
			ctx.type_input_event__owned_prop_ids.append(prop_id)
			if WyncXtrap.prop_is_predicted(ctx, prop_id):
				ctx.type_input_event__predicted_owned_prop_ids.append(prop_id)

	for prop_id in ctx.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		var is_predicted := WyncXtrap.prop_is_predicted(ctx, prop_id)

		if prop.prop_type == WyncEntityProp.PROP_TYPE.EVENT:
			if is_predicted:
				ctx.type_event__predicted_prop_ids.append(prop_id)

			# MAYBEDO: check if we don't own it?
			if prop.is_auxiliar_prop:
				# MAYBEDO: drop this check
				var master_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
				assert(master_prop != null)
				if WyncXtrap.prop_is_predicted(ctx, prop.auxiliar_delta_events_prop_id):
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
		if not WyncXtrap.entity_is_predicted(ctx, wync_entity_id):
			continue
		ctx.predicted_integrable_entity_ids.append(wync_entity_id)

	for wync_entity_id in ctx.tracked_entities.keys():
		if not WyncXtrap.entity_is_predicted(ctx, wync_entity_id):
			continue
		ctx.predicted_entity_ids.append(wync_entity_id)


static func wync_xtrap_auxiliar_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id: int in ctx.type_state__delta_prop_ids:
		var prop := ctx.props[prop_id]
		var aux_prop = ctx.props[prop.auxiliar_delta_events_prop_id]
		prop.current_delta_events.clear()
		aux_prop.current_undo_delta_events.clear()


static func wync_xtrap_props_update_predicted_states_ticks(ctx: WyncCtx, props_ids: Array, target_tick: int) -> void:
	
	for prop_id: int in props_ids:
		
		var prop := ctx.props[prop_id]
		if prop == null:
			continue
		if not WyncXtrap.prop_is_predicted(ctx, prop_id):
			continue

		# update store predicted state metadata
		
		prop.pred_prev.server_tick = target_tick -1
		prop.pred_curr.server_tick = target_tick


## TODO: maybe we could compute this every time we get an update?
## Only predicted props
## Exclude props I own (Or just exclude TYPE_INPUT?) What about events or delta props?
static func wync_xtrap_entity_get_last_received_tick_from_pred_props (ctx: WyncCtx, entity_id: int) -> int:
	if not WyncTrack.is_entity_tracked(ctx, entity_id):
		return -1

	var last_tick = -1 
	for prop_id: int in ctx.entity_has_props[entity_id]:

		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue

		# for rela props, ignore base, instead count auxiliar last tick
		if prop.relative_syncable:
			continue

		var prop_last_tick = prop.last_ticks_received.get_relative(0)
		if prop_last_tick == -1:
			continue

		if ctx.client_owns_prop[ctx.my_peer_id].has(prop_id):
			continue

		if last_tick == -1:
			last_tick = prop_last_tick
		else:
			last_tick = min(last_tick, prop_last_tick)

	return last_tick


static func wync_xtrap_internal_tick_end(ctx: WyncCtx, tick: int):

	# wync bookkeeping
	# --------------------------------------------------

	# integration functions

	for wync_entity_id: int in ctx.predicted_integrable_entity_ids:
		# TODO: Move this to user level wrapper
		var int_fun = WyncIntegrate.entity_get_integrate_fun(ctx, wync_entity_id)
		int_fun.call()

	# extract / poll for generated predicted _undo delta events_

	for prop_id: int in ctx.type_event__predicted_auxiliar_prop_ids:

		var aux_prop := ctx.props[prop_id]

		var entity_id = WyncTrack.prop_get_entity(ctx, aux_prop.auxiliar_delta_events_prop_id)
		if !ctx.global_entity_ids_to_predict.has(entity_id):
			continue
		
		var undo_events = aux_prop.current_undo_delta_events.duplicate(true)
		aux_prop.confirmed_states_undo.insert_at(tick, undo_events)
		aux_prop.confirmed_states_undo_tick.insert_at(tick, tick)

	ctx.last_tick_predicted = tick
