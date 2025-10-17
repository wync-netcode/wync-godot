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
	prop = prop as WyncProp
	return prop.relative_sync_enabled


# ==================================================
# WRAPPER
# ==================================================


## Delta Blueprints Setup
## Should be setup only at the beginning
## @returns int. delta blueprint id
static func create_delta_blueprint (ctx: WyncCtx) -> int:
	var id = ctx.wrapper.delta_blueprints.size()
	var blueprint = WyncWrapperStructs.WyncDeltaBlueprint.new()
	ctx.wrapper.delta_blueprints.append(blueprint)
	return id
	

static func delta_blueprint_exists (ctx: WyncCtx, delta_blueprint_id: int) -> bool:
	if delta_blueprint_id < 0 || delta_blueprint_id >= ctx.wrapper.delta_blueprints.size():
		return false
	var blueprint = ctx.wrapper.delta_blueprints[delta_blueprint_id]
	if blueprint is not WyncWrapperStructs.WyncDeltaBlueprint:
		return false
	return true


## @returns Optional<WyncWrapperStructs.WyncDeltaBlueprint>
static func get_delta_blueprint (ctx: WyncCtx, delta_blueprint_id: int) -> WyncWrapperStructs.WyncDeltaBlueprint:
	if delta_blueprint_exists(ctx, delta_blueprint_id):
		return ctx.wrapper.delta_blueprints[delta_blueprint_id]
	return null


static func delta_blueprint_register_event (
	ctx: WyncCtx,
	delta_blueprint_id: int,
	event_type_id: int,
	handler: Callable
	#user_context: Variant
	) -> Error:
	
	var blueprint = get_delta_blueprint(ctx, delta_blueprint_id)
	if blueprint is not WyncWrapperStructs.WyncDeltaBlueprint:
		return ERR_DOES_NOT_EXIST

	# NOTE: check argument integrity
	blueprint.event_handlers[event_type_id] = handler
	#blueprint.handler_user_context[event_type_id] = user_context
	return OK


## Prop Utils
## ================================================================


## commits a delta event to this tick
static func delta_prop_push_event_to_current \
	(ctx: WyncCtx, prop_id: int, event_type_id: int, event_id: int) -> int:
	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncProp
	if not prop.relative_sync_enabled:
		return 2
	var blueprint = get_delta_blueprint(ctx, prop.co_rela.delta_blueprint_id)
	if not blueprint:
		return 3
	blueprint = blueprint as WyncWrapperStructs.WyncDeltaBlueprint

	# check if this event belongs to this blueprint
	if not blueprint.event_handlers.has(event_type_id):
		return 4

	# append event to current delta events
	prop.co_rela.current_delta_events.append(event_id)
	Log.outc(ctx, "delta_prop_push_event_to_current | delta sync | ticks(%s) event_list %s" % [ctx.common.ticks, prop.co_rela.current_delta_events])
	return OK


static func merge_event_to_state_real_state \
	(ctx: WyncCtx, prop_id: int, event_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1

	if not prop.relative_sync_enabled:
		return 2

	if (ctx.common.is_client
		&& not WyncXtrap.prop_is_predicted(ctx, prop_id)
		&& ctx.co_pred.currently_on_predicted_tick
		):
		return OK

	# If merging a _delta event_ WHILE PREDICTING (that is, not when merging
	# received data) we make sure to always produce an _undo delta event_ 

	var is_client_predicting = ctx.common.is_client \
			&& WyncXtrap.prop_is_predicted(ctx, prop_id) \
			&& ctx.co_pred.currently_on_predicted_tick 

	var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
	if user_ctx == null:
		return 3

	var result: Array[Variant] = _merge_event_to_state(ctx, prop, event_id, user_ctx, true)

	# cache _undo delta event_
	if (is_client_predicting && result[0] == OK && result[1] != null):
		prop.co_rela.current_undo_delta_events.append(result[1])
		Log.outc(ctx, "debugrela produced undo delta event %s" % [prop.co_rela.current_undo_delta_events])
	
	return result[0]


## TODO: Move to wrapper
## @returns Tuple[int, Optional<int>]. [0] -> Error, [1] -> undo_event_id || null
static func _merge_event_to_state \
	(ctx: WyncCtx, prop: WyncProp, event_id: int, state: Variant, requires_undo: bool) -> Array[Variant]:
	# get event transform function
	# TODO: Make a new function get_event(event_id)
	
	if not ctx.co_events.events.has(event_id):
		Log.errc(ctx, "delta sync | couldn't find event id(%s)" % [event_id])
		return [14, null]
	var event_data = (ctx.co_events.events[event_id] as WyncCtx.WyncEvent).data

	# NOTE: Maybe confirm this prop's blueprint supports this event_type

	var blueprint = get_delta_blueprint(ctx, prop.co_rela.delta_blueprint_id)
	if blueprint == null:
		return [15, null]
	blueprint = blueprint as WyncWrapperStructs.WyncDeltaBlueprint

	var handler = blueprint.event_handlers[event_data.event_type_id] as Callable
	var result: Array[int] = handler.call(state, event_data, requires_undo, ctx if requires_undo else null)
	if result[0] != OK: result[0] += 100

	return result


static func predicted_event_props_clear_events(ctx: WyncCtx):
	for prop_id in ctx.co_filter_c.type_event__predicted_prop_ids:
		var setter = ctx.wrapper.prop_setter[prop_id]
		var user_cxt = ctx.wrapper.prop_user_ctx[prop_id]
		setter.call(user_cxt, [] as Array[int])
