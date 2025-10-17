class_name WyncWrapper


static func wrapper_initialize(ctx: WyncCtx):
	ctx.wrapper = WyncWrapperStructs.WyncWrapperCtx.new()
	ctx.wrapper.prop_user_ctx.resize(WyncCtx.MAX_PROPS)
	ctx.wrapper.prop_getter.resize(WyncCtx.MAX_PROPS)
	ctx.wrapper.prop_setter.resize(WyncCtx.MAX_PROPS)
	ctx.wrapper.lerp_type_to_lerp_function.resize(WyncWrapperStructs.WRAPPER_MAX_USER_TYPES)
	ctx.wrapper.lerp_function = []


static func wync_set_prop_callbacks \
	(ctx: WyncCtx, prop_id: int, user_ctx: Variant, getter: Callable, setter: Callable):
	ctx.wrapper.prop_user_ctx[prop_id] = user_ctx
	ctx.wrapper.prop_getter[prop_id] = getter
	ctx.wrapper.prop_setter[prop_id] = setter


# ==================================================
# Wrapper functions that aren't worth creating a 
# wrapper version of their respective modules
# ==================================================


# Part of module 'wync_input'. Used in 'wync_flow'
static func wync_buffer_inputs(ctx: WyncCtx):
	
	if not ctx.common.connected: # TODO: delme
		return

	## Buffer state (extract) from props we own, to create a state history
	
	for prop_id: int in ctx.co_filter_c.type_input_event__owned_prop_ids:

		var input_prop := WyncTrack.get_prop_unsafe(ctx, prop_id)
		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		var new_state = getter.call(user_ctx)
		assert(new_state != null)

		WyncStateStore.wync_prop_state_buffer_insert(ctx, input_prop, ctx.co_pred.target_tick, new_state)


# Part of module 'wync_state_store'. Used in 'wync_flow'
static func extract_data_to_tick(ctx: WyncCtx, save_on_tick: int = -1):

	var prop: WyncProp = null
	var prop_aux: WyncProp = null
	var getter: Variant = null # Callable*
	var user_ctx: Variant = null

	# Save state history per tick

	for prop_id in ctx.co_filter_s.filtered_regular_extractable_prop_ids:
		prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		getter = ctx.wrapper.prop_getter[prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		
		WyncStateStore.wync_prop_state_buffer_insert(ctx, prop, save_on_tick, getter.call(user_ctx))
		# Note: safe to call user getter like that?

	# extracts events ids from auxiliar delta props

	for prop_id in ctx.co_filter_s.filtered_delta_prop_ids:
		
		prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		prop_aux = WyncTrack.get_prop_unsafe(ctx, prop.auxiliar_delta_events_prop_id)
		
		getter = ctx.wrapper.prop_getter[prop.auxiliar_delta_events_prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop.auxiliar_delta_events_prop_id]
		WyncStateStore.wync_prop_state_buffer_insert(ctx, prop_aux, save_on_tick, getter.call(user_ctx))



# Used for timewarp
# Note: Receives a list of prop_ids, that way the user can
# determine which to extract, instead of extracting them all, maybe 
# useful for chunked big worlds.
static func extract_data_to_tick_for_regular_state_props(
	ctx: WyncCtx, save_on_tick: int, prop_ids: Array[int]):

	var prop: WyncProp = null
	var getter: Variant = null # Callable*
	var user_ctx: Variant = null

	# Save state history per tick

	for prop_id in prop_ids:
		prop = WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			Log.errc(ctx, "Invalid prop id %s" % [prop_id])
			continue
		getter = ctx.wrapper.prop_getter[prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		
		WyncStateStore.wync_prop_state_buffer_insert(ctx, prop, save_on_tick, getter.call(user_ctx))


static func extract_rela_prop_fullsnapshot_to_tick (
	ctx: WyncCtx, save_on_tick: int = -1):

	var prop: WyncProp = null
	var getter: Variant = null # Callable*
	var user_ctx: Variant = null

	ctx.co_throttling.rela_prop_ids_for_full_snapshot.sort()
	var last_prop_id = -1

	for prop_id: int in ctx.co_throttling.rela_prop_ids_for_full_snapshot:

		# sorted list might contain duplicated entries
		if prop_id == last_prop_id:
			continue
		last_prop_id = prop_id

		prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		getter = ctx.wrapper.prop_getter[prop_id]
		user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		
		WyncStateStore.wync_prop_state_buffer_insert(ctx, prop, save_on_tick, getter.call(user_ctx))

		Log.outc(ctx, "debugdelta, extracting fullsnap for prop(%s) %s" %
		[ prop_id, prop.name_id ])


# Part of module 'wync_input'. Used in 'wync_flow'
static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for prop_id in ctx.co_filter_s.filtered_clients_input_and_event_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)	

		var input = WyncStateStore.wync_prop_state_buffer_get(prop, ctx.common.ticks)
		if input == null:
			Log.warc(ctx, "couldn't find input (%s) for tick (%s)" % [prop.name_id, ctx.common.ticks])
			continue

		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_ctx, input)

	return OK
