class_name WyncActions


# Q: Difference between "Actions" and "Events Consumed"?
# A:
# * Events Consumed: (Server only) A way for the server to support executing
#   client events without repeating them.
# * Actions: (Client only) Used when predicting, a way for the client to know
#   a given action on a repeating predicted tick was already executed.


# ==================================================================
# "Events Consumed" prop module / add-on


static func global_event_consume_tick \
	(ctx: WyncCtx, wync_peer_id: int, channel: int, tick: int, event_id: int) -> void:
	
	assert(channel >= 0 && channel < ctx.common.max_channels)
	assert(wync_peer_id >= 0 && wync_peer_id < ctx.common.max_peers)
	
	var prop_id: int = ctx.co_events.prop_id_by_peer_by_channel[wync_peer_id][channel]
	var prop_channel := WyncTrack.get_prop_unsafe(ctx, prop_id)

	var consumed_event_ids_tick: int = prop_channel.co_consumed.events_consumed_at_tick_tick.get_at(tick)
	if tick != consumed_event_ids_tick:
		return

	var consumed_events: Array[int] = prop_channel.co_consumed.events_consumed_at_tick.get_at(tick)
	consumed_events.append(event_id)


static func module_events_consumed_advance_tick(ctx: WyncCtx):
	var tick = ctx.common.ticks

	# TODO: Index props with "event consume module"
	for prop_id: int in ctx.co_track.active_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		if not prop.consumed_events_enabled:
			continue

		prop.co_consumed.events_consumed_at_tick_tick.insert_at(tick, tick)
		var event_ids: Array[int] = prop.co_consumed.events_consumed_at_tick.get_at(tick)
		event_ids.clear()


# ==================================================================
# Action functions, not related to Events


static func action_already_ran_on_tick(ctx: WyncCtx, predicted_tick: int, action_id: String) -> bool:
	var action_set = ctx.co_pred.tick_action_history.get_at(predicted_tick)
	if action_set is not Dictionary:
		return false
	action_set = action_set as Dictionary
	return action_set.has(action_id)


static func action_mark_as_ran_on_tick(ctx: WyncCtx, predicted_tick: int, action_id: String) -> int:
	var action_set = ctx.co_pred.tick_action_history.get_at(predicted_tick)
	# This error should never happen as long as we initialize it correctly
	# However, the user might provide any 'tick' which would result in
	# confusing results
	if action_set is not Dictionary:
		return 1
	action_set = action_set as Dictionary
	action_set[action_id] = true
	return 0


# run once each game tick
static func action_tick_history_reset(ctx: WyncCtx, predicted_tick: int) -> int:
	var action_set = ctx.co_pred.tick_action_history.get_at(predicted_tick)
	if action_set is not Dictionary:
		return 1
	action_set = action_set as Dictionary
	action_set.clear()
	return 0
