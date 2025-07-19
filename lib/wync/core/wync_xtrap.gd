class_name WyncXtrap
## wync_xtrap.h, includes public and wrapper

## functions to preform extrapolation / prediction


# ==================================================
# PUBLIC API
# ==================================================


static func wync_xtrap_preparation(ctx: WyncCtx) -> int:
	if ctx.last_tick_received == 0:
		return 1
	ctx.currently_on_predicted_tick = true
	ctx.xtrap_is_local_tick_duplicated = false
	ctx.xtrap_prev_local_tick = null # Optional<int>
	ctx.xtrap_local_tick = null # Optional<int>

	if (
		ctx.last_tick_received_at_tick_prev != ctx.last_tick_received_at_tick ||
		ctx.last_tick_received > ctx.first_tick_predicted
	):
		ctx.pred_intented_first_tick = ctx.last_tick_received +1
		ctx.last_tick_received_at_tick_prev = ctx.last_tick_received_at_tick
	else:
		ctx.pred_intented_first_tick = ctx.last_tick_predicted
	#ctx.last_tick_received_at_tick_prev = ctx.last_tick_received_at_tick

	# DEBUG: Uncomment this line to overwrite the decision
	#ctx.pred_intented_first_tick = ctx.last_tick_received +1

	ctx.first_tick_predicted = ctx.pred_intented_first_tick

	if ctx.co_predict_data.target_tick <= ctx.co_ticks.server_ticks:
		return 2
	if ctx.pred_intented_first_tick - ctx.max_prediction_tick_threeshold < 0:
		return 3

	return OK


# TODO: Redo these comments
# which entities shouldnt' be predicted in this tick:
# * entities containing delta props
# * entities with an already confirmed state for this tick or a higher tick
# * entities that haven't received new state
# These props need their state reset to that tick. Why here this ???
# * props that are predicted and already have a confirmed state for this tick

# Composes a list of ids of entities TO PREDICT THIS TICK
static func wync_xtrap_regular_entities_to_predict(ctx: WyncCtx, tick: int):
	ctx.global_entity_ids_to_predict.clear()

	var entity_last_tick: int
	var entity_last_predicted_tick: int

	# iterate each entity and determine if they should be predicted
	for entity_id in ctx.predicted_entity_ids:

		entity_last_tick = ctx.entity_last_received_tick[entity_id]
		
		# no history
		if entity_last_tick == -1:
			continue

		# already have confirmed state + it's regular prop
		elif entity_last_tick >= tick:
			continue

		entity_last_predicted_tick = ctx.entity_last_predicted_tick[entity_id]

		# already predicted
		if tick <= entity_last_predicted_tick:
			continue

		# else, aprove prediction and assume this tick as predicted
		if tick > entity_last_predicted_tick:
			ctx.entity_last_predicted_tick[entity_id] = tick

		ctx.global_entity_ids_to_predict.append(entity_id)


static func wync_xtrap_termination(ctx: WyncCtx):
	WyncDeltaSyncUtilsInternal.auxiliar_props_clear_current_delta_events(ctx)
	WyncDeltaSyncUtils.predicted_event_props_clear_events(ctx)
	ctx.currently_on_predicted_tick = false
	ctx.global_entity_ids_to_predict.clear()


# NOTE: rename to prop_enable_prediction
static func prop_set_predict(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	ctx.props_to_predict.append(prop_id)

	# TODO: set only if it isn't _delta prop_
	#prop.pred_curr = NetTickData.new()
	#prop.pred_prev = NetTickData.new()
	return OK


# TODO: this is not very well optimized
static func prop_is_predicted(ctx: WyncCtx, prop_id: int) -> bool:
	return ctx.props_to_predict.has(prop_id)
	

static func entity_is_predicted(ctx: WyncCtx, entity_id: int) -> bool:
	if not ctx.entity_has_props.has(entity_id):
		return false
	for prop_id in ctx.entity_has_props[entity_id]:
		if prop_is_predicted(ctx, prop_id):
			return true
	return false


# ==================================================
# WRAPPER
# ==================================================


static func wync_xtrap_tick_init(ctx: WyncCtx, tick: int):
	ctx.current_predicted_tick = tick

	# reset predicted inputs / events
	WyncXtrap.wync_xtrap_reset_all_state_to_confirmed_tick_absolute(ctx, ctx.type_input_event__predicted_owned_prop_ids, tick)

	# reset predicted regular
	#WyncWrapper.wync_xtrap_reset_all_state_to_confirmed_tick_absolute(ctx, ctx.type_state__predicted_regular_prop_ids, tick)

	# clearing delta events before predicting, predicted delta events will be
	# polled and cached at the end of the predicted tick
	WyncXtrapInternal.wync_xtrap_auxiliar_props_clear_current_delta_events(ctx)


static func wync_xtrap_tick_end(ctx: WyncCtx, tick: int):

	wync_xtrap_save_latest_predicted_state(ctx, tick)
	WyncXtrapInternal.wync_xtrap_internal_tick_end(ctx, tick)


## private
## for inputs / events
static func wync_xtrap_reset_all_state_to_confirmed_tick_absolute(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	for prop_id: int in prop_ids:
		var prop := ctx.props[prop_id]
		var value = WyncEntityProp.saved_state_get(prop, tick)
		if value == null:
			continue
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, value)


## private
static func wync_xtrap_props_update_predicted_states_data(ctx: WyncCtx, props_ids: Array) -> void:
	
	for prop_id: int in props_ids:
		
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop == null:
			continue
		if prop.relative_syncable:
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


static func wync_xtrap_save_latest_predicted_state(ctx: WyncCtx, tick: int):

	# (run on last two iterations)

	var store_predicted_states = tick > (ctx.co_predict_data.target_tick - 1)
	if store_predicted_states:
		for wync_entity_id: int in ctx.predicted_entity_ids:
			# TODO: Make this call user-level
			# store predicted states
			WyncXtrap.wync_xtrap_props_update_predicted_states_data(ctx, ctx.entity_has_props[wync_entity_id])

			# update/store predicted state metadata
			WyncXtrapInternal.wync_xtrap_props_update_predicted_states_ticks(ctx, ctx.entity_has_props[wync_entity_id], ctx.co_predict_data.target_tick)
