class_name WyncStateSet


# ==================================================
# PUBLIC API
# ==================================================


static func does_delta_prop_has_undo_events(ctx: WyncCtx, prop_id: int, tick: int) -> bool:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		Log.errc(ctx, "couldn't find prop id(%s)" % [prop_id])
		return false
	prop = prop as WyncProp

	var aux_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
	if aux_prop == null:
		Log.errc(ctx, "WyncStateSet | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id])
		return false
	aux_prop = aux_prop as WyncProp

	if aux_prop.confirmed_states_undo_tick.get_at(tick) != tick:
		return false

	var undo_event_id_list = aux_prop.confirmed_states_undo.get_at(tick)
	if undo_event_id_list == null || undo_event_id_list is not Array[int]:
		return false
			
	return not (undo_event_id_list as Array).is_empty()


# ==================================================
# WRAPPER
# ==================================================

## timewarp, server only
static func wync_reset_state_to_saved_absolute (
	ctx: WyncCtx, prop_ids: Array[int], tick: int):

	var value

	# then interpolate them

	for prop_id: int in prop_ids:

		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		value = WyncProp.saved_state_get(prop, tick)

		if value == null:
			Log.warc(ctx, "debugtimewarp, prop_id %s NOT FOUND tick %s" % [prop_id, tick])
			if prop.prop_type != WyncProp.PROP_TYPE.INPUT:
				assert(false)
				print_stack()

			# Note: What to do with missing inputs?

			continue

		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, value)


static func reset_all_state_to_confirmed_tick_relative(
	ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick)
		if last_confirmed_tick == -1:
			continue

		var state = WyncProp.saved_state_get(prop, last_confirmed_tick as int)
		if state == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, state)

		if prop.relative_syncable:
			Log.outc(ctx, "debugdelta, Setted absolute state for prop(%s) %s" % [
			prop_id, prop.name_id])


## sets props state to last confirmed received state
## NOTE: optimize which to reset, by knowing which were modified/new state gotten
## NOTE: reset only when new data is available
	
static func wync_reset_props_to_latest_value (ctx: WyncCtx):
	
	ctx.type_state__newstate_prop_ids.clear()

	for prop_id: int in ctx.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		if prop.prop_type != WyncProp.PROP_TYPE.STATE:
			continue
		if not prop.just_received_new_state:
			continue

		prop.just_received_new_state = false
		ctx.type_state__newstate_prop_ids.append(prop_id)

		if WyncXtrap.prop_is_predicted(ctx, prop_id):

			if not prop.relative_syncable: # regular prop
				var entity_id = WyncTrack.prop_get_entity(ctx, prop_id)
				ctx.entity_last_predicted_tick[entity_id] = prop.last_ticks_received.get_relative(0)
			else:

				# get aux_prop and clean the confirmed_states_undo
				var aux_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
				for j in range(ctx.first_tick_predicted, ctx.last_tick_predicted +1):

					WyncProp.saved_state_insert(ctx, aux_prop, j, [] as Array[int])

					aux_prop.confirmed_states_undo.insert_at(j, [] as Array[int])
					aux_prop.confirmed_states_undo_tick.insert_at(j, j)
		
	# rest state to _canonic_

	reset_all_state_to_confirmed_tick_relative(ctx, ctx.type_state__newstate_prop_ids, 0)

	# only rollback if new state was received and is applicable:

	delta_props_update_and_apply_delta_events(ctx, ctx.type_state__delta_prop_ids)
	
	# NOTE: Physics integration would go after this


static func predicted_delta_props_rollback_to_canonic_state (ctx: WyncCtx, prop_ids: Array[int]):

	#if (ctx.last_tick_predicted - ctx.first_tick_predicted) == 0:
		#return

	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary

	for prop_id: int in prop_ids:
		var prop = WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			Log.errc(ctx, "WyncStateSet | delta sync | couldn't find prop id(%s)" % [prop_id])
			continue 
		prop = prop as WyncProp

		# not checking if props are valid for this operation or not
		# that should be checked before passing prop_ids to this function

		var aux_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.errc(ctx, "WyncStateSet | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id])
			continue
		aux_prop = aux_prop as WyncProp

		# NOTE: Are we sure we have delta_props_last_tick[prop_id]?
		if not delta_props_last_tick.has(prop_id) || delta_props_last_tick[prop_id] == -1:
			continue

		# apply events in order

		var last_uptodate_tick = delta_props_last_tick[prop_id]

		for tick: int in range(ctx.last_tick_predicted, last_uptodate_tick, -1):

			if aux_prop.confirmed_states_undo_tick.get_at(tick) != tick:
				# NOTE: for now, if we find nothing, we do nothing.
				# We assume this tick just wasn't predicted.
				# Needs more testing to be sure this is safe to ignore.
				# Otherwise we could just store ticks that were actually predicted.
				break
			var undo_event_id_list = aux_prop.confirmed_states_undo.get_at(tick) as Array[int]

			#Log.outc(ctx, "debugrela | gonna rollback prop %s tick %s event_list %s" % [prop_id, tick, undo_event_id_list])

			# merge state

			for event_id: int in undo_event_id_list:
				WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

				if not ctx.events.has(event_id):
					assert(false)
					continue

				#var event_data = (ctx.events[event_id] as WyncEvent).data
				#Log.outc(ctx, "debugrela debug_pred_delta_event | applied undo_events predicted_tick(%s) %s %s" % [tick, undo_event_id_list, HashUtils.object_to_dictionary(event_data)])

			# clear already applied undo events

			undo_event_id_list.clear()


# should be run on client each logic frame
# applies delta events and keeps delta props healthy
# FIXME: it seems this functions is not well optimized, I think it's running
#     like 30 cycles per individual prop_id.

static func delta_props_update_and_apply_delta_events(ctx: WyncCtx, prop_ids: Array[int]):

	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary

	for prop_id: int in prop_ids:
		var prop = WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			Log.errc(ctx, "WyncStateSet | delta sync | couldn't find prop id(%s)" % [prop_id])
			continue 
		prop = prop as WyncProp

		var aux_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.errc(ctx, "WyncStateSet | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id])
			continue
		aux_prop = aux_prop as WyncProp
		
		# NOTE: Are we sure we have delta_props_last_tick[prop_id]?
		if not delta_props_last_tick.has(prop_id) || delta_props_last_tick[prop_id] == -1:
			continue

		# vars for rollback of predicted states

		var already_rollbacked = false

		# Fixed now? FIXME: There will be UB if between the range before last_tick_received we didn't
		# receive an input
		# resulting in usage of old values
		# apply events in order

		var applied_events_until = -1

		for tick: int in range(delta_props_last_tick[prop_id] +1, ctx.last_tick_received +1):

			var delta_event_list = WyncProp.saved_state_get(aux_prop, tick)
			if delta_event_list is not Array[int]:
				# FIXME: document this
				#Log.errc(ctx, "WyncStateSet | delta sync | we don't have an input for this tick %s" % [tick], Log.TAG_LATEST_VALUE)
				break

			# before applying any events:
			# first confirm we have the event data for all events on tick

			var has_all_event_data = true
			var events_we_dont_have := []

			for event_id: int in delta_event_list:
				if WyncDeltaSyncUtilsInternal.event_is_healthy(ctx, event_id) != OK:
					has_all_event_data = false
					events_we_dont_have.append(event_id)
					#break

			if not has_all_event_data:
				Log.errc(ctx, "Some delta event data is missing from this tick (%s), we don't have %s" % [tick, events_we_dont_have])
				#if prop_id == 15:
				#	assert(false)
				break

			# if delta_event_list.size() <= 0: also rollback if this current tick
			# contains undo events...... But what about previous ticks? No problem
			# because ticks are applied sequencially, so no ticks will be skipped.

			# NOTE: if we don't apply any events, then there is no need to modify
			# ctx.entity_last_predicted_tick, that way there is no need to repredict
			# for no reason.

			var we_modified_or_applied_events = false

			if delta_event_list.size() <= 0:

				if WyncStateSet.does_delta_prop_has_undo_events(ctx, prop_id, tick):

					if !already_rollbacked:
						already_rollbacked = true
						predicted_delta_props_rollback_to_canonic_state (ctx, [prop_id])
						we_modified_or_applied_events = true

						Log.outc(ctx, "debugrela applied NO events (and therefore rollbacked) tick %s UNDO DELTA FOUND" % [tick])

			if delta_event_list.size() > 0:

				we_modified_or_applied_events = true

				if !already_rollbacked:
					already_rollbacked = true
					predicted_delta_props_rollback_to_canonic_state (ctx, [prop_id])

				for event_id: int in delta_event_list:
					var err = WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

					# this error is almost fatal, should never happen, it could fail because of not finding the event
					# in that case we're gonna continue in hopes we eventually get the event data
					# TODO: implement measures against this ever happening, write tests againts this.
					if err:
						Log.errc(ctx, "delta sync | VERY BAD, couldn't apply event id(%s) err(%s)" % [event_id, err])
						assert(false)
						break
					Log.outc(ctx, "delta sync | client consumed delta event %d" % [event_id])

			# commit

				Log.outc(ctx, "debugrela applied events %s (and therefore rollbacked) tick %s" % [delta_event_list, tick])

			applied_events_until = tick
			delta_props_last_tick[prop_id] = applied_events_until
			#if prop_id == 16:
				#Log.outc(ctx, "debugrela,,, updated last canonic tick to %s" % [tick])

			# Note: this should work but it feels like a workaround. Question: when can
			# this variable be modified?

			# if predicted
			var entity_id = WyncTrack.prop_get_entity(ctx, prop_id)
			if (we_modified_or_applied_events || 
				ctx.entity_last_predicted_tick[entity_id] < applied_events_until):
				ctx.entity_last_predicted_tick[entity_id] = applied_events_until

			# Note: you have last tick applied per prop and globally, so the user
			# can choose what to use
