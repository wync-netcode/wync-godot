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
	prop.relative_change_event_list = RingBuffer.new(ctx.max_prop_relative_sync_history_ticks)
	prop.relative_change_real_tick = RingBuffer.new(ctx.max_prop_relative_sync_history_ticks)
	for i in range(ctx.max_prop_relative_sync_history_ticks):
		prop.relative_change_event_list.insert_at(i, [] as Array[int])
		prop.relative_change_real_tick.insert_at(i, -1 as int)

	# confirmed states will always be of size 1
	# index 0 -> store a copy of the base tick state
	# index 1? -> store a copy of the real state when doing timewarp
	prop.confirmed_states = RingBuffer.new(1)

	return OK


static func prop_is_relative_syncable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return false
	prop = prop as WyncEntityProp
	return prop.relative_syncable


static func delta_sync_prop_push_event_to_tick \
	(ctx: WyncCtx, prop_id: int, event_type_id: int, event_id: int, tick: int) -> int:
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

	# push it
	var event_list = prop.relative_change_event_list.get_at(tick) as Array
	event_list.push_back(event_id)

	# TODO: avoid inserting this multiple times (each time an event is pushed)...
	prop.relative_change_real_tick.insert_at(tick, tick as int)

	Log.out(ctx, "delta sync | event_list %s" % [event_list])
	return OK


static func merge_event_to_state(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	# TODO: We need a way to get a hold of the real data to apply the transforms...
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	var state_pointer = prop.getter_pointer.call()
	if state_pointer == null:
		return 3

	# get event transform function
	
	if not ctx.events.has(event_id):
		return 4
	var event_data = (ctx.events[event_id] as WyncEvent).data

	# NOTE: Maybe confirm this prop's blueprint supports this event_type

	var blueprint = get_delta_blueprint(ctx, prop.delta_blueprint_id)
	if blueprint == null:
		return 5
	blueprint = blueprint as WyncDeltaBlueprint

	var handler = blueprint.event_handlers[event_data.event_type_id] as Callable
	handler.call(state_pointer, event_data)

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
