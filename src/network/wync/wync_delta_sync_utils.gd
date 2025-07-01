class_name WyncDeltaSyncUtils


## Relative Synchronization functions
## Blueprint functions are part of the Wrapper


# ==================================================
# PUBLIC API
# ==================================================


static func prop_is_relative_syncable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return false
	prop = prop as WyncEntityProp
	return prop.relative_syncable


# ==================================================
# WRAPPER
# ==================================================


## Delta Blueprints Setup
## Should be setup only at the beginning
## @returns int. delta blueprint id
static func create_delta_blueprint (ctx: WyncCtx) -> int:
	var id = ctx.wrapper.delta_blueprints.size()
	var blueprint = WyncDeltaBlueprint.new()
	ctx.wrapper.delta_blueprints.append(blueprint)
	return id
	

static func delta_blueprint_exists (ctx: WyncCtx, delta_blueprint_id: int) -> bool:
	if delta_blueprint_id < 0 || delta_blueprint_id >= ctx.wrapper.delta_blueprints.size():
		return false
	var blueprint = ctx.wrapper.delta_blueprints[delta_blueprint_id]
	if blueprint is not WyncDeltaBlueprint:
		return false
	return true


## @returns Optional<WyncDeltaBlueprint>
static func get_delta_blueprint (ctx: WyncCtx, delta_blueprint_id: int) -> WyncDeltaBlueprint:
	if delta_blueprint_exists(ctx, delta_blueprint_id):
		return ctx.wrapper.delta_blueprints[delta_blueprint_id]
	return null


# TODO: Move to wrapper
static func delta_blueprint_register_event (
	ctx: WyncCtx,
	delta_blueprint_id: int,
	event_type_id: int,
	handler: Callable
	#user_context: Variant
	) -> Error:
	
	var blueprint = get_delta_blueprint(ctx, delta_blueprint_id)
	if blueprint is not WyncDeltaBlueprint:
		return ERR_DOES_NOT_EXIST

	# NOTE: check argument integrity
	blueprint.event_handlers[event_type_id] = handler
	#blueprint.handler_user_context[event_type_id] = user_context
	return OK


## Prop Utils
## ================================================================


static func prop_set_relative_syncable (
	ctx: WyncCtx,
	entity_id: int,
	prop_id: int,
	delta_blueprint_id: int,
	predictable: bool = false,
	#state_pointer: Variant,
	# timewarpable: bool # NOT PLANNED
	) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1

	if not delta_blueprint_exists(ctx, delta_blueprint_id):
		Log.errc(ctx, "delta blueprint(%s) doesn't exists" % [delta_blueprint_id])
		return 2
	
	prop.relative_syncable = true
	#prop.state_pointer = state_pointer
	prop.delta_blueprint_id = delta_blueprint_id

	# depending on the features and if it's server or client we'll need different things
	# * delta prop, server side, no timewarp: real state, delta event buffer
	# * delta prop, client side, no prediction: real state, received delta event buffer
	# * delta prop, client side, predictable: base state, real state, received delta event buffer, predicted delta event buffer
	# * delta prop, server side, timewarpable: base state, real state, delta event buffer

	# assuming no timewarpable
	# minimum storage allowed 0 or 2
	var buffer_items = 2
	prop.saved_states = RingBuffer.new(buffer_items, null) 
	prop.tick_to_state_id = RingBuffer.new(buffer_items, -1)
	prop.state_id_to_tick = RingBuffer.new(buffer_items, -1)
	prop.state_id_to_local_tick = RingBuffer.new(buffer_items, -1)
	#prop.saved_states = RingBuffer.new(2, null) 
	#prop.tick_to_state_id = RingBuffer.new(2, -1)
	#prop.state_id_to_tick = RingBuffer.new(2, -1)
	#prop.state_id_to_local_tick = RingBuffer.new(2, -1)


	var need_undo_events = false
	if ctx.is_client && predictable:
		need_undo_events = true
		WyncXtrap.prop_set_predict(ctx, prop_id)

	# setup auxiliar prop for delta change events
	prop.current_delta_events = [] as Array[int]
	var events_prop_id = WyncTrack.prop_register_minimal(
		ctx,
		entity_id,
		"auxiliar_delta_events",
		WyncEntityProp.PROP_TYPE.EVENT
	)
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		events_prop_id,
		prop,
		func(prop_ctx: WyncEntityProp):
			return prop_ctx.current_delta_events.duplicate(true),
		func(prop_ctx: WyncEntityProp, events: Array):
			prop_ctx.current_delta_events.clear()
			# NOTE: somehow can't check cast like this `if events is not Array[int]:`
			prop_ctx.current_delta_events.append_array(events)
	)
	# FIXME: shouldn't we be setting the auxiliar as predicted?
	# the main prop IS marked as predicted, however, auxiliar props are NOT marked
	# but we still ALLOCATE and USE the extra buffer space, including space for 'confirmed_states_undo'
	WyncDeltaSyncUtilsInternal.prop_set_auxiliar(ctx, events_prop_id, prop_id, need_undo_events)
	#WyncTrack.prop_set_prediction_duplication(ctx, events_prop_id, false)

	prop.auxiliar_delta_events_prop_id = events_prop_id

	return OK




## commits a delta event to this tick
static func delta_prop_push_event_to_current \
	(ctx: WyncCtx, prop_id: int, event_type_id: int, event_id: int) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2
	var blueprint = get_delta_blueprint(ctx, prop.delta_blueprint_id)
	if not blueprint:
		return 3
	blueprint = blueprint as WyncDeltaBlueprint

	# check if this event belongs to this blueprint
	if not blueprint.event_handlers.has(event_type_id):
		return 4

	# append event to current delta events
	prop.current_delta_events.append(event_id)
	Log.out("delta_prop_push_event_to_current | delta sync | ticks(%s) event_list %s" % [ctx.co_ticks.ticks, prop.current_delta_events], Log.TAG_DELTA_EVENT)
	return OK


"""
static func merge_event_to_state_real_state(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	var state_pointer = prop.state_pointer.call()
	if state_pointer == null:
		return 3

	var result = _merge_event_to_state(ctx, prop, event_id, state_pointer, false)
	return result[0]
"""

static func merge_event_to_state_real_state \
	(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	if (ctx.is_client
		&& not WyncXtrap.prop_is_predicted(ctx, prop_id)
		&& ctx.currently_on_predicted_tick
		):
		return OK

# every time we merge a delta event WHILE PREDICTING (that is, not when merging received data)
# we make sure to always produce an _undo delta event_ 

	var is_client_predicting = ctx.is_client \
			&& WyncXtrap.prop_is_predicted(ctx, prop_id) \
			&& ctx.currently_on_predicted_tick 
	var aux_prop = null # : WyncEntityProp*

	# get auxiliar prop
	if (is_client_predicting):
		aux_prop = WyncTrack.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			return 3
		aux_prop = aux_prop as WyncEntityProp
		if not aux_prop.is_auxiliar_prop:
			return 4

	var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
	if user_ctx == null:
		return 5

	var result: Array[Variant] = _merge_event_to_state(ctx, prop, event_id, user_ctx, true)

	# cache _undo delta event_ to aux_prop
	if (is_client_predicting):
		if result[0] == OK:
			if result[1] != null:
				aux_prop.current_undo_delta_events.append(result[1])
				Log.outc(ctx, "debugrela produced undo delta event %s" % [aux_prop.current_undo_delta_events])
	
	return result[0]


## TODO: Move to wrapper
## @returns Tuple[int, Optional<int>]. [0] -> Error, [1] -> undo_event_id || null
static func _merge_event_to_state \
	(ctx: WyncCtx, prop: WyncEntityProp, event_id: int, state: Variant, requires_undo: bool) -> Array[Variant]:
	# get event transform function
	# TODO: Make a new function get_event(event_id)
	
	if not ctx.events.has(event_id):
		Log.err("delta sync | couldn't find event id(%s)" % [event_id], Log.TAG_DELTA_EVENT)
		return [14, null]
	var event_data = (ctx.events[event_id] as WyncEvent).data

	# NOTE: Maybe confirm this prop's blueprint supports this event_type

	var blueprint = get_delta_blueprint(ctx, prop.delta_blueprint_id)
	if blueprint == null:
		return [15, null]
	blueprint = blueprint as WyncDeltaBlueprint

	var handler = blueprint.event_handlers[event_data.event_type_id] as Callable
	var result: Array[int] = handler.call(state, event_data, requires_undo, ctx if requires_undo else null)
	if result[0] != OK: result[0] += 100

	# Reminder: Handler interface
	# (state: Variant, event: WyncEvent.EventData, requires_undo: bool, ctx: WyncCtx*) -> [err, undo_event_id]:

	return result


## Use this function when setting up an relative_syncable prop.
## Use this function when you need to reset the state after you modified it to something
## you rather not represent with events

#static func delta_sync_prop_extract_state (ctx: WyncCtx, prop_id: int) -> int:
	#var prop = WyncTrack.get_prop(ctx, prop_id)
	#if prop == null:
		#return 1
	#prop = prop as WyncEntityProp
	#if not prop.relative_syncable:
		#return 2
	#prop.confirmed_states.insert_at(0, prop.getter.call(prop.user_ctx_pointer))

	## TODO: clear all events, they're all invalid now
	## TODO: copy to state 1	
	#return OK


## Logic Loops
## ================================================================


## execute this function on prop creation
## and periodically? for clients that are just joining...
## Need to make sure clients have a history of last state received about _delta sync props_
## NOTE: Is this necessary at all?
"""
static func delta_sync_prop_initialize_clients (ctx: WyncCtx, prop_id: int) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	for client_id in range(1, ctx.peers.size()):
		# TODO: check client is healthy

		var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
		var knows_about_prop = client_relative_props.has(prop_id)
		if not knows_about_prop:
			client_relative_props[prop_id] = -1

	return OK
"""


static func predicted_event_props_clear_events(ctx: WyncCtx):
	for prop_id in ctx.type_event__predicted_prop_ids:
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_cxt = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_cxt, [] as Array[int])


"""
static func owned_props_clear_events(ctx: WyncCtx):
	for prop_id in ctx.type_input_event__owned_prop_ids:
		var prop = WyncTrack.get_prop_unsafe(ctx, prop_id)
		if prop.prop_type != WyncEntityProp.PROP_TYPE.EVENT:
			continue
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_cxt = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_cxt, [] as Array[int])
"""




