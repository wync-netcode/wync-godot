class_name WyncXtrapInternal
## wync_xtrap_internal.h


# Note: further optimization could involve removing adding singular props from the list
# TODO: rename, server doesn't do any xtrap related
static func wync_xtrap_server_filter_prop_ids(ctx: WyncCtx):
	if not ctx.common.was_any_prop_added_deleted:
		return
	ctx.common.was_any_prop_added_deleted = false
	Log.outc(ctx, "debug filters")

	ctx.co_filter_s.filtered_clients_input_and_event_prop_ids.clear()
	ctx.co_filter_s.filtered_delta_prop_ids.clear()
	ctx.co_filter_s.filtered_regular_extractable_prop_ids.clear()
	ctx.co_filter_s.filtered_regular_timewarpable_prop_ids.clear()

	for client_id in range(1, ctx.common.peers.size()):
		for prop_id in ctx.co_clientauth.client_owns_prop[client_id]:
			var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
			if (prop.prop_type != WyncCtx.PROP_TYPE.INPUT &&
				prop.prop_type != WyncCtx.PROP_TYPE.EVENT):
				continue
			ctx.co_filter_s.filtered_clients_input_and_event_prop_ids.append(prop_id)

	for prop_id in ctx.co_track.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		if (prop.prop_type != WyncCtx.PROP_TYPE.STATE &&
			prop.prop_type != WyncCtx.PROP_TYPE.INPUT):
			continue

		if (prop.relative_sync_enabled &&
			prop.prop_type == WyncCtx.PROP_TYPE.STATE):
			ctx.co_filter_s.filtered_delta_prop_ids.append(prop_id)
			# TODO: Check if it has a healthy _auxiliar prop_

		else:
			if (prop.prop_type == WyncCtx.PROP_TYPE.STATE):
				ctx.co_filter_s.filtered_regular_extractable_prop_ids.append(prop_id)

			if prop.timewarp_enabled:
				ctx.co_filter_s.filtered_regular_timewarpable_prop_ids.append(prop_id)
				if prop.lerp_enabled:
					ctx.co_filter_s.filtered_regular_timewarpable_interpolable_prop_ids.append(prop_id)


static func wync_xtrap_client_filter_prop_ids(ctx: WyncCtx):
	if not ctx.common.was_any_prop_added_deleted:
		return
	ctx.common.was_any_prop_added_deleted = false
	Log.outc(ctx, "debug filters")

	ctx.co_filter_c.type_input_event__owned_prop_ids.clear()
	ctx.co_filter_c.type_input_event__predicted_owned_prop_ids.clear()
	ctx.co_filter_c.type_event__predicted_prop_ids.clear()
	ctx.co_filter_c.type_state__delta_prop_ids.clear()
	ctx.co_filter_c.type_state__predicted_delta_prop_ids.clear()
	ctx.co_filter_c.type_state__predicted_regular_prop_ids.clear()
	ctx.co_filter_c.type_state__interpolated_regular_prop_ids.clear()

	ctx.co_pred.predicted_entity_ids.clear()

	# Where are active props set?

	for prop_id in ctx.co_clientauth.client_owns_prop[ctx.common.my_peer_id]:
		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.prop_type != WyncCtx.PROP_TYPE.STATE:
			ctx.co_filter_c.type_input_event__owned_prop_ids.append(prop_id)
			if WyncXtrap.prop_is_predicted(ctx, prop_id):
				ctx.co_filter_c.type_input_event__predicted_owned_prop_ids.append(prop_id)

	for prop_id in ctx.co_track.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		var is_predicted := WyncXtrap.prop_is_predicted(ctx, prop_id)

		if prop.prop_type == WyncCtx.PROP_TYPE.EVENT:
			if is_predicted:
				ctx.co_filter_c.type_event__predicted_prop_ids.append(prop_id)

		if prop.prop_type == WyncCtx.PROP_TYPE.STATE:
			if prop.relative_sync_enabled:
				ctx.co_filter_c.type_state__delta_prop_ids.append(prop_id)
				if is_predicted:
					ctx.co_filter_c.type_state__predicted_delta_prop_ids.append(prop_id)
			else: # regular
				if is_predicted:
					ctx.co_filter_c.type_state__predicted_regular_prop_ids.append(prop_id)
				if prop.lerp_enabled:
					ctx.co_filter_c.type_state__interpolated_regular_prop_ids.append(prop_id)

	for wync_entity_id in ctx.co_track.tracked_entities.keys():
		if not WyncXtrap.entity_is_predicted(ctx, wync_entity_id):
			continue
		ctx.co_pred.predicted_entity_ids.append(wync_entity_id)


static func wync_xtrap_delta_props_clear_current_delta_events(ctx: WyncCtx):
	for prop_id: int in ctx.co_filter_c.type_state__delta_prop_ids:
		var prop := ctx.co_track.props[prop_id]
		prop.co_rela.current_delta_events.clear()
		prop.co_rela.current_undo_delta_events.clear()


static func wync_xtrap_props_update_predicted_states_ticks(ctx: WyncCtx, props_ids: Array, target_tick: int) -> void:
	
	for prop_id: int in props_ids:
		
		var prop := ctx.co_track.props[prop_id]
		if prop == null:
			continue
		if not WyncXtrap.prop_is_predicted(ctx, prop_id):
			continue

		# update store predicted state metadata
		
		prop.co_xtrap.pred_prev.server_tick = target_tick -1
		prop.co_xtrap.pred_curr.server_tick = target_tick


## TODO: maybe we could compute this every time we get an update?
## Only predicted props
## Exclude props I own (Or just exclude TYPE_INPUT?) What about events or delta props?
static func wync_xtrap_entity_get_last_received_tick_from_pred_props (ctx: WyncCtx, entity_id: int) -> int:
	if not WyncTrack.is_entity_tracked(ctx, entity_id):
		return -1

	var last_tick = -1 
	for prop_id: int in ctx.co_track.entity_has_props[entity_id]:

		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue

		# for rela props, ignore base, instead count auxiliar last tick
		if prop.relative_sync_enabled:
			continue

		var prop_last_tick = prop.last_ticks_received.get_relative(0)
		if prop_last_tick == -1:
			continue

		if ctx.co_clientauth.client_owns_prop[ctx.common.my_peer_id].has(prop_id):
			continue

		if last_tick == -1:
			last_tick = prop_last_tick
		else:
			last_tick = min(last_tick, prop_last_tick)

	return last_tick


static func wync_xtrap_internal_tick_end(ctx: WyncCtx, tick: int):

	# wync bookkeeping
	# --------------------------------------------------

	# extract / poll for generated predicted _undo delta events_

	for prop_id: int in ctx.co_filter_c.type_state__predicted_delta_prop_ids:

		var prop := ctx.co_track.props[prop_id]

		var entity_id = WyncTrack.prop_get_entity(ctx, prop.auxiliar_delta_events_prop_id)
		# Note: Why check if these are supposed to be already predicted...
		if !ctx.co_pred.global_entity_ids_to_predict.has(entity_id):
			continue
		
		var undo_events = prop.co_rela.current_undo_delta_events.duplicate(true)
		prop.co_rela.confirmed_states_undo.insert_at(tick, undo_events)
		prop.co_rela.confirmed_states_undo_tick.insert_at(tick, tick)

	ctx.co_pred.last_tick_predicted = tick

	# NOTE: Integration functions would go here
