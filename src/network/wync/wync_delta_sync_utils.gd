class_name WyncDeltaSyncUtils

## Relative Synchronization functions


## Delta Blueprints Setup
## Should be setup only at the beginning
## ================================================================

## @returns int. delta blueprint id
static func create_delta_blueprint (ctx: WyncCtx) -> int:
	var id = ctx.delta_blueprints.size()
	var blueprint = WyncDeltaBlueprint.new()

	blueprint.relative_changes_list._init(ctx.max_prop_relative_sync_history_ticks)
	for i in range(ctx.max_prop_relative_sync_history_ticks):
		blueprint.relative_changes_list[i] = [] as Array[int]

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


static func delta_blueprint_register_event \
	(ctx: WyncCtx, delta_blueprint_id: int, event_type_id: int, handler: Callable) -> Error:
	
	var blueprint = get_delta_blueprint(ctx, delta_blueprint_id)
	if blueprint is not WyncDeltaBlueprint:
		return ERR_DOES_NOT_EXIST

	# NOTE: check argument integrity
	blueprint.event_handlers[event_type_id] = handler
	return OK


## Prop Utils
## ================================================================


static func prop_set_relative_syncable (ctx: WyncCtx, prop_id: int, delta_blueprint_id: int) -> Error:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return ERR_INVALID_DATA
	prop = prop as WyncEntityProp

	if not delta_blueprint_exists(ctx, delta_blueprint_id):
		return ERR_DOES_NOT_EXIST

	prop.relative_syncable = true
	prop.delta_blueprint_id = delta_blueprint_id
	return OK


static func prop_is_relative_syncable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return false
	prop = prop as WyncEntityProp
	return prop.relative_syncable

