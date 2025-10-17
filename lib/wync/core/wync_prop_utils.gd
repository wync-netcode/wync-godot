class_name WyncPropUtils


static func prop_enable_prediction(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null || prop.xtrap_enabled:
		return 1

	prop.xtrap_enabled = true
	prop.co_xtrap = WyncProp.Xtrap.new()
	prop.co_xtrap.pred_curr = WyncCtx.NetTickData.new()
	prop.co_xtrap.pred_prev = WyncCtx.NetTickData.new()

	return OK


# * the server needs to know for subtick timewarping
# * client needs to know for visual lerping
static func prop_enable_interpolation(
	ctx: WyncCtx, prop_id: int, user_data_type: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null || prop.lerp_enabled:
		return 1
	assert(user_data_type > 0) # avoid accidental default values

	prop.lerp_enabled = true
	prop.co_lerp = WyncProp.Lerp.new()
	prop.co_lerp.lerp_user_data_type = user_data_type

	return OK


# Reference:
# depending on the features and if it's server or client we'll need
# different things
# * delta prop, server side, no timewarp: real state, delta event buffer
# * delta prop, client side, no prediction: real state, received delta
#   event buffer
# * delta prop, client side, predictable: base state, real state, received
#   delta event buffer, predicted delta event buffer
# * delta prop, server side, timewarpable: base state, real state, delta
#   event buffer

static func prop_enable_relative_sync (
	ctx: WyncCtx,
	entity_id: int,
	prop_id: int,
	delta_blueprint_id: int,
	predictable: bool = false,
	) -> int:

	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null || prop.relative_sync_enabled:
		return 1

	if not WyncDeltaSyncUtils.delta_blueprint_exists(ctx, delta_blueprint_id):
		Log.errc(ctx, "delta blueprint(%s) doesn't exists" % [delta_blueprint_id])
		return 2
	
	prop.relative_sync_enabled = true

	prop.co_rela = WyncProp.Rela.new()
	prop.co_rela.delta_blueprint_id = delta_blueprint_id

	# assuming no timewarpable
	# minimum storage allowed 0 or 2

	var buffer_items = 2
	prop.statebff.saved_states = RingBuffer.new(buffer_items, null) 
	prop.statebff.tick_to_state_id = RingBuffer.new(buffer_items, -1)
	prop.statebff.state_id_to_tick = RingBuffer.new(buffer_items, -1)
	prop.statebff.state_id_to_local_tick = RingBuffer.new(buffer_items, -1)

	var need_undo_events = false
	if ctx.common.is_client && predictable:
		need_undo_events = true
		WyncPropUtils.prop_enable_prediction(ctx, prop_id)

	# setup auxiliar prop for delta change events
	prop.co_rela.current_delta_events = [] as Array[int]
	var events_prop_id = WyncTrack.prop_register_minimal(
		ctx,
		entity_id,
		"auxiliar_delta_events",
		WyncCtx.PROP_TYPE.EVENT
	)
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		events_prop_id,
		prop,
		func(prop_ctx: WyncProp):
			return prop_ctx.co_rela.current_delta_events.duplicate(true),
		func(prop_ctx: WyncProp, events: Array):
			prop_ctx.co_rela.current_delta_events.clear()
			# NOTE: somehow can't check cast like this `if events is not Array[int]:`
			prop_ctx.co_rela.current_delta_events.append_array(events)
	)

	# undo events are only for prediction and timewarp
	if need_undo_events:
		prop.co_rela.confirmed_states_undo = \
			RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, [])
		prop.co_rela.confirmed_states_undo_tick = \
			RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)

	# Q: shouldn't we be setting the auxiliar as predicted?
	# A: TODO

	var aux_prop := WyncTrack.get_prop(ctx, events_prop_id)
	if aux_prop == null:
		return 3

	if (aux_prop.prop_type != WyncCtx.PROP_TYPE.EVENT):
		return 4

	aux_prop.is_auxiliar_prop = true
	aux_prop.auxiliar_delta_events_prop_id = prop_id

	WyncPropUtils.prop_enable_prediction(ctx, events_prop_id)

	prop.auxiliar_delta_events_prop_id = events_prop_id

	return OK


# server only?
static func prop_enable_module_events_consumed(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null || prop.consumed_events_enabled:
		return 1
	prop.consumed_events_enabled = true

	prop.co_consumed = WyncProp.Consumed.new()
	prop.co_consumed.events_consumed_at_tick = RingBuffer.new(ctx.common.max_age_user_events_for_consumption, [] as Array[int])
	prop.co_consumed.events_consumed_at_tick_tick = RingBuffer.new(ctx.common.max_age_user_events_for_consumption, -1)
	return OK
