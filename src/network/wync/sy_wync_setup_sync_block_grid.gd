class_name SyWyncSetupSyncBlockGrid
extends System
const label: StringName = StringName("SyWyncSetupSyncBlockGrid")


# This function aims to setup synchronization info for entities

func _ready():
	components = [
		CoActor.label,
		CoBlockGrid.label,
		CoActorRegisteredFlag.label,
		-CoFlagWyncEntityTracked.label
	]
	super()


func on_process(entities, _data, _delta):
	for entity in entities:
		if entity.name == "EnBlockGrid":
			setup_block_grid(entity)
		if entity.name == "EnBlockGridDelta":
			setup_block_grid_delta(entity)


func setup_block_grid(entity: Entity):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	
	# TODO: Move this elsewhere
	# Setup random blocks on server
	if !WyncUtils.is_client(wync_ctx):
		co_block_grid.generate_random_blocks()
	
	WyncUtils.track_entity(wync_ctx, co_actor.id)
	var _blocks_prop = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"blocks",
		WyncEntityProp.DATA_TYPE.ANY,
		func() -> CoBlockGrid: return co_block_grid.make_duplicate(),
		func(block_grid: CoBlockGrid): co_block_grid.set_from_instance(block_grid),
	)
	
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out(self, "wync: Registered entity %s with id %s" % [entity, co_actor.id])


func setup_block_grid_delta(entity: Entity):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	
	# TODO: Move this elsewhere
	# Setup random blocks on server
	if not WyncUtils.is_client(wync_ctx):
		co_block_grid.generate_random_blocks()
	
	WyncUtils.track_entity(wync_ctx, co_actor.id)
	var blocks_prop = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"blocks",
		WyncEntityProp.DATA_TYPE.ANY,
		func() -> CoBlockGrid: return co_block_grid.make_duplicate(),
		func(block_grid: CoBlockGrid): co_block_grid.set_from_instance(block_grid),
	)

	# setup relative synchronization blueprints

	var blueprint_id = WyncDeltaSyncUtils.create_delta_blueprint(wync_ctx)
	WyncDeltaSyncUtils.delta_blueprint_register_event(
		wync_ctx,
		blueprint_id,
		GameInfo.EVENT_PLAYER_BLOCK_BREAK,
		SyWyncSetupSyncBlockGrid.blueprint_handle_event_player_block_break
	)

	# hook Prop to Blueprint

	var err = WyncDeltaSyncUtils.prop_set_relative_syncable(wync_ctx, blocks_prop, blueprint_id)
	if err > 0:
		Log.err(self, "Couldn't set relative sync to Prop id(%s) err(%s)" % [blocks_prop, err])
		return

	# required to extract state on start

	WyncDeltaSyncUtils.delta_sync_prop_extract_state(wync_ctx, blocks_prop)
	
	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)
	Log.out(self, "wync: Registered entity %s with id %s" % [entity, co_actor.id])


# Why do we need user context? Why isn't everything that we need contained in the event data?
# Remember that these delta changes ARE NOT EVENTS but just changes over time.

# Receive this data, and modify it

static func blueprint_handle_event_player_block_break \
	(data: Variant, event: WyncEvent.EventData) -> int:

	# Cast data to correct type
	# TODO: Maybe also tell me the data_type that is stored in the prop.

	if data is not CoBlockGrid:
		Log.err(null, "EVENT_PLAYER_BLOCK_BREAK | Data is not CoBlockGrid")
		return 1
	var co_block_grid = data as CoBlockGrid
	var block_pos = event.arg_data[0] as Vector2i

	# Shouldn't need to check because the user was who submitted the event
	# But let's do it anyway to be safe

	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(null, "EVENT_PLAYER_BLOCK_BREAK | block_pos %s is invalid" % [block_pos])
		return 1
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.AIR
	return 0

