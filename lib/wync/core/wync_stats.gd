class_name WyncStats


## Call every time a WyncPktSnap contains _the prob_prop id_
static func wync_try_to_update_prob_prop_rate(ctx: WyncCtx):
	if ctx.co_metrics.low_priority_entity_tick_last_update == ctx.common.ticks:
		return

	var tick_rate = ctx.common.ticks - ctx.co_metrics.low_priority_entity_tick_last_update -1
	ctx.co_metrics.low_priority_entity_update_rate_sliding_window.push(tick_rate)
	ctx.co_metrics.low_priority_entity_tick_last_update = ctx.common.ticks


## Call every physic tick
static func wync_system_calculate_server_tick_rate(ctx: WyncCtx):
	var accumulative = 0
	var amount = 0
	for i in range(ctx.SERVER_TICK_RATE_SLIDING_WINDOW_SIZE):
		var value = ctx.co_metrics.server_tick_rate_sliding_window.get_at(i)
		if value is not int:
			continue
		accumulative += value
		amount += 1
	if amount <= 0:
		ctx.co_metrics.server_tick_rate = 0
	else:
		ctx.co_metrics.server_tick_rate = accumulative / float(amount)


## Call every physic tick
static func wync_system_calculate_prob_prop_rate(ctx: WyncCtx):
	var accumulative = 0
	var amount = 0
	for i in range(ctx.co_metrics.low_priority_entity_update_rate_sliding_window_size):
		var value = ctx.co_metrics.low_priority_entity_update_rate_sliding_window.get_at(i)
		if value is not int:
			continue
		accumulative += value
		amount += 1
	if amount <= 0:
		ctx.co_metrics.low_priority_entity_update_rate = 0
	else:
		ctx.co_metrics.low_priority_entity_update_rate = accumulative / float(amount)

	# TODO: Move this elsewhere
	# calculate prediction threeshold
	# adding 1 of padding for good measure
	ctx.co_pred.max_prediction_tick_threeshold = int(ceil(ctx.co_metrics.low_priority_entity_update_rate)) + 1

	# 'REGULAR_PROP_CACHED_STATE_AMOUNT -1' because for xtrap we need to set it
	# to the value just before 'ctx.max_prediction_tick_threeshold -1'
	ctx.co_pred.max_prediction_tick_threeshold = min(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT-1, ctx.co_pred.max_prediction_tick_threeshold)


## Call every time a packet is received
static func _wync_report_update_received(ctx: WyncCtx):
	if ctx.co_metrics.tick_last_packet_received_from_server == ctx.common.ticks:
		return

	var tick_rate = ctx.common.ticks - ctx.co_metrics.tick_last_packet_received_from_server -1
	ctx.co_metrics.server_tick_rate_sliding_window.push(tick_rate)
	ctx.co_metrics.tick_last_packet_received_from_server = ctx.common.ticks


## calculate statistic data per tick
static func wync_system_calculate_data_per_tick(ctx: WyncCtx):

	var data_sent = ctx.common.out_packets_size_limit - ctx.common.out_packets_size_remaining_chars
	ctx.co_metrics.debug_data_per_tick_current = data_sent

	ctx.co_metrics.debug_ticks_sent += 1
	ctx.co_metrics.debug_data_per_tick_total_mean = (ctx.co_metrics.debug_data_per_tick_total_mean * (ctx.co_metrics.debug_ticks_sent -1) + data_sent) / float(ctx.co_metrics.debug_ticks_sent)

	ctx.co_metrics.debug_data_per_tick_sliding_window.push(data_sent)
	var data_sent_acc = 0
	for i in range(ctx.co_metrics.debug_data_per_tick_sliding_window_size):
		var value = ctx.co_metrics.debug_data_per_tick_sliding_window.get_at(i)
		if value is int:
			data_sent_acc += ctx.co_metrics.debug_data_per_tick_sliding_window.get_at(i)
	ctx.co_metrics.debug_data_per_tick_sliding_window_mean = data_sent_acc / ctx.co_metrics.debug_data_per_tick_sliding_window_size


# ==================================================
# WRAPPER
# ==================================================


# setup "prob prop"
static func setup_entity_prob_for_entity_update_delay_ticks(ctx: WyncCtx, peer_id: int) -> int:

	# The prob prop acts is a low priority entity to sync, it's purpose it's to
	# allow us to measure how much ticks of delay there are between updates for
	# a especific single prop, based on that we can get a better stimate for
	# _prediction threeshold_
	
	var entity_id = WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS
	WyncTrack.track_entity(ctx, entity_id, -1)
	var prop_prob = WyncTrack.prop_register_minimal(
		ctx,
		entity_id,
		"entity_prob",
		WyncProp.PROP_TYPE.STATE
	)
	# TODO: internal functions shouldn't be using wrapper functions...
	# Maybe we can treat these differently? These are all internal, so it
	# doesn't make sense to require external functions like the wrapper's
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		prop_prob,
		ctx,
		func(p_ctx: Variant) -> int: # getter
			# use any value that constantly changes, don't really need to read it
			return (p_ctx as WyncCtx).common.ticks, 
		func(_prob_ctx: Variant, _value: Variant): # setter
			pass,
	)
	if prop_prob != -1:
		ctx.co_metrics.PROP_ID_PROB = prop_prob

	# add as local existing prop
	if not ctx.common.is_client:
		WyncTrack.wync_add_local_existing_entity(ctx, peer_id, entity_id)

	return 0
