class_name WyncDeltaSyncUtils

## Relative Synchronization functions


## Delta Blueprints Setup
## Should be setup only at the beginning
## ================================================================

## @returns int. delta blueprint id
static func create_delta_blueprint (ctx: WyncCtx) -> int:
	var id = ctx.delta_blueprints.size()
	var blueprint = WyncDeltaBlueprint.new()
	ctx.delta_blueprints.append(blueprint)
	return id
	

static func delta_blueprint_exists (ctx: WyncCtx, delta_blueprint_id: int) -> bool:
	if delta_blueprint_id < 0 || delta_blueprint_id >= ctx.delta_blueprints.size():
		return false
	var blueprint = ctx.delta_blueprints[delta_blueprint_id]
	if blueprint is not WyncDeltaBlueprint:
		return false
	return true


## @returns Optional<WyncDeltaBlueprint>
static func get_delta_blueprint (ctx: WyncCtx, delta_blueprint_id: int) -> WyncDeltaBlueprint:
	if delta_blueprint_exists(ctx, delta_blueprint_id):
		return ctx.delta_blueprints[delta_blueprint_id]
	return null


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
	prop_id: int,
	delta_blueprint_id: int,
	getter_pointer: Callable
	# timewarpable: bool # TODO
	) -> Error:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return ERR_INVALID_DATA
	prop = prop as WyncEntityProp

	if not delta_blueprint_exists(ctx, delta_blueprint_id):
		return ERR_DOES_NOT_EXIST
	
	prop.relative_syncable = true
	prop.getter_pointer = getter_pointer
	prop.delta_blueprint_id = delta_blueprint_id
	prop.relative_change_event_list = FIFORingAny.new(ctx.max_prop_relative_sync_history_ticks)
	prop.relative_change_real_tick = FIFORingAny.new(ctx.max_prop_relative_sync_history_ticks)

	# allocate event arrays
	for i in range(ctx.max_prop_relative_sync_history_ticks):
		prop.relative_change_event_list.push_head([] as Array[int])
		prop.relative_change_real_tick.push_head(-1)
	for i in range(ctx.max_prop_relative_sync_history_ticks):
		prop.relative_change_event_list.pop_tail()
		prop.relative_change_real_tick.pop_tail()

	# depending on the features and if it's server or client we'll need different things
	# * delta prop, server side, no timewarp: real state, delta event buffer
	# * delta prop, client side, no prediction: real state, received delta event buffer
	# * delta prop, client side, predictable: base state, real state, received delta event buffer, predicted delta event buffer
	# * delta prop, server side, timewarpable: base state, real state, delta event buffer

	# assuming no timewarpable
	prop.confirmed_states = RingBuffer.new(0)

	#if timewarpable or predictable:
	#prop.confirmed_states = RingBuffer.new(1)

	return OK


static func prop_is_relative_syncable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return false
	prop = prop as WyncEntityProp
	return prop.relative_syncable


## commits a delta change event to this tick
static func delta_sync_prop_push_event_to_tick \
	(ctx: WyncCtx, prop_id: int, event_type_id: int, event_id: int, co_ticks: CoTicks) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
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

	# get event array

	var event_array = null # *Array[int]
	var latest_event_tick = prop.relative_change_real_tick.get_head() as int

	# push a new array

	if co_ticks.ticks > latest_event_tick:
		var err1 = prop.relative_change_event_list.extend_head()
		var err2 = prop.relative_change_real_tick.push_head(co_ticks.ticks)
		if (err1 + err2) != OK:
			Log.out(ctx, "delta sync | extend_head, push_head | err1(%s) err2(%s)" % [err1, err2])
			return 5

		event_array = prop.relative_change_event_list.get_head()
		event_array = event_array as Array[int]
		event_array.clear()
		# NOTE: Maybe it's not necessary to clean it, it should get cleaned when it's consumed.
		# if it's dirty, that means we're overwriting events, so the history buffer is too short

	# use the existing array for this tick

	elif co_ticks.ticks == latest_event_tick:
		event_array = prop.relative_change_event_list.get_head()
		event_array = event_array as Array[int]

	else:
		Log.err(ctx, "delta sync | Trying to push delta event to an old tick. co_ticks(%s) latest_tick(%s)" % [co_ticks.ticks, latest_event_tick])
		return 6

	event_array.push_back(event_id)

	Log.out(ctx, "delta sync | ticks(%s) event_list %s" % [co_ticks.ticks, event_array])
	return OK


# FIXME: this function name doesn't describe what it does
static func merge_event_to_state_confirmed_state(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	# TODO
	return 1
	#var prop = WyncUtils.get_prop(ctx, prop_id)
	#if prop == null:
		#return 1
	#prop = prop as WyncEntityProp
	#if not prop.relative_syncable:
		#return 2

	#var state_pointer = prop.getter_pointer.call()
	#if state_pointer == null:
		#return 3

	#return _merge_event_to_state(ctx, prop, event_id, state_pointer)


static func merge_event_to_state_real_state(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	var state_pointer = prop.getter_pointer.call()
	if state_pointer == null:
		return 3

	return _merge_event_to_state(ctx, prop, event_id, state_pointer)


static func _merge_event_to_state(ctx: WyncCtx, prop: WyncEntityProp, event_id: int, state: Variant) -> int:
	# get event transform function
	# TODO: Make a new function get_event(event_id)
	
	if not ctx.events.has(event_id):
		Log.err(ctx, "delta sync | couldn't find event id(%s)" % [event_id])
		return 14
	var event_data = (ctx.events[event_id] as WyncEvent).data

	# NOTE: Maybe confirm this prop's blueprint supports this event_type

	var blueprint = get_delta_blueprint(ctx, prop.delta_blueprint_id)
	if blueprint == null:
		return 15
	blueprint = blueprint as WyncDeltaBlueprint

	var handler = blueprint.event_handlers[event_data.event_type_id] as Callable
	handler.call(state, event_data)

	# Handler prototype reminder: func (data: Variant, event: WyncEvent.EventData)

	return 0


## Use this function when setting up an relative_syncable prop.
## Use this function when you need to reset the state after you modified it to something
## you rather not represent with events

static func delta_sync_prop_extract_state (ctx: WyncCtx, prop_id: int) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2
	prop.confirmed_states.insert_at(0, prop.getter.call())

	# TODO: clear all events, they're all invalid now
	# TODO: copy to state 1	
	return OK


## Logic Loops
## ================================================================


## execute this function on prop creation
## and periodically? for clients that are just joining...
## Need to make sure clients have a history of last state received about _delta sync props_
## NOTE: Is this necessary at all?
static func delta_sync_prop_initialize_clients (ctx: WyncCtx, prop_id: int) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
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
