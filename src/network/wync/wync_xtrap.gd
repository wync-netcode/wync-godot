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


static func wync_xtrap_tick_init(ctx: WyncCtx, tick: int) -> int:
	ctx.current_predicted_tick = tick
	
	# --------------------------------------------------
	# ALL INPUT/EVENT PROPS, no excepcion for now
	# TODO: identify which I own and which belong to my foes'

	# set events inputs to corresponding value depending on tick
	# TODO: could this be generalized with 'wync_input_props_set_tick_value' ?
	
	for prop_id: int in ctx.active_prop_ids:
		
		var prop := WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if not WyncUtils.prop_is_predicted(ctx, prop_id):
			continue
		if prop.data_type not in [WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			continue

		if prop.confirmed_states_tick.get_at(tick) != tick:
			continue
		var input_snap = prop.confirmed_states.get_at(tick)

		# honor no duplication
		if (prop.data_type == WyncEntityProp.DATA_TYPE.EVENT
			&& ctx.xtrap_is_local_tick_duplicated):

			if (not prop.allow_duplication_on_tick_skip):

				# set default value, in the future we might support INPUT type as well
				input_snap = [] as Array[int]
			
		if input_snap == null:
			continue
		prop.setter.call(prop.user_ctx_pointer, input_snap)

		# INPUT/EVENTs don't need integration functions

	# clearing delta events before predicting, predicted delta events will be
	# polled and cached at the end of the predicted tick
	WyncDeltaSyncUtils.auxiliar_props_clear_current_delta_events(ctx)

	return OK


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

	var target_tick = ctx.co_predict_data.target_tick

	# wync bookkeeping
	# --------------------------------------------------

	for wync_entity_id: int in ctx.tracked_entities.keys():
	
		if !WyncUtils.entity_is_predicted(ctx, wync_entity_id):
			continue
		
		# store predicted states
		# (run on last two iterations)
		
		if tick > (target_tick -1):
			WyncXtrap.props_update_predicted_states_data(ctx, ctx.entity_has_props[wync_entity_id])

		# integration functions
		
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, wync_entity_id)
		if int_fun is Callable:
			int_fun.call()

		# update/store predicted state metadata
	
		WyncXtrap.props_update_predicted_states_ticks(ctx, ctx.entity_has_props[wync_entity_id], target_tick)

	# extract / poll for generated predicted _undo delta events_

	if tick >= ctx.pred_intented_first_tick:
		for prop_id: int in ctx.active_prop_ids:
			var prop = WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			prop = prop as WyncEntityProp
			if not prop.relative_syncable:
				continue
			if not WyncUtils.prop_is_predicted(ctx, prop_id):
				continue
				
			var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
			if aux_prop == null:
				assert(false)
				continue
			aux_prop = aux_prop as WyncEntityProp
			
			var undo_events = aux_prop.current_undo_delta_events.duplicate(true)
			aux_prop.confirmed_states_undo.insert_at(tick, undo_events)
			aux_prop.confirmed_states_undo_tick.insert_at(tick, tick)
			#Log.out("for SyWyncLatestValue | saving undo_events for tick %s" % [tick], Log.TAG_XTRAP)

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
		
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop == null:
			continue

		# update store predicted state metadata
		
		prop.pred_prev.server_tick = target_tick -1
		prop.pred_curr.server_tick = target_tick
