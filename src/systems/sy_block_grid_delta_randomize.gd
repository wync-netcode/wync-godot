extends System
class_name SyBlockGridDeltaRandomize
const label: StringName = StringName("SyBlockGridDeltaRandomize")


func on_process(_entities, _data, _delta):
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	if co_ticks.ticks % Engine.physics_ticks_per_second != 0:
		return

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	#var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	#if en_block_grid:
		#insert_random_block(wync_ctx, en_block_grid)
	#else:
		#Log.err(self, "coulnd't get singleton EnBlockGrid")

	var en_block_grid_delta = ECS.get_singleton_entity(self, "EnBlockGridDelta")
	if en_block_grid_delta:
		insert_random_block(wync_ctx, en_block_grid_delta)
	else:
		Log.err(self, "coulnd't get singleton EnBlockGridDelta")


func insert_random_block(wync_ctx: WyncCtx, en_block_grid: Entity):
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_actor = en_block_grid.get_component(CoActor.label) as CoActor
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid

	var block_pos = Vector2i(randi_range(0, CoBlockGrid.LENGTH-1), randi_range(0, CoBlockGrid.LENGTH-1))
	var block_type = [CoBlockGrid.BLOCK.AIR, CoBlockGrid.BLOCK.STONE, CoBlockGrid.BLOCK.TNT].pick_random()

	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = block_type

	# get prop_id from entity

	var prop_blocks_id = WyncUtils.entity_get_prop_id(wync_ctx, co_actor.id, "blocks")
	if prop_blocks_id == -1:
		Log.err(self, "Couldn't find prop [blocks] for entity %s" % [co_actor.id])

	# Commit a Delta Event here

	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE, 2)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.VECTOR2, block_pos)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 1, WyncEntityProp.DATA_TYPE.INT, block_type)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)

	var err = WyncDeltaSyncUtils.delta_sync_prop_push_event_to_tick(wync_ctx, prop_blocks_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks.ticks)
	if err != OK:
		Log.err(self, "Failed to push delta-sync-event err(%s)" % [err])
	WyncDeltaSyncUtils.merge_event_to_state(wync_ctx, prop_blocks_id, event_id)
	

