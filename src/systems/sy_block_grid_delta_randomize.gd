extends System
class_name SyBlockGridDeltaRandomize
const label: StringName = StringName("SyBlockGridDeltaRandomize")


func on_process(_entities, _data, _delta):
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	if not (
		(co_ticks.ticks > 10 && co_ticks.ticks < 50)
		#|| (co_ticks.ticks > 150 && co_ticks.ticks < 170)
		):
		return
	#if not (
		#(co_ticks.ticks % (Engine.physics_ticks_per_second * 2) == 0)
		## || (co_ticks.ticks % 17 == 0)
		## || (co_ticks.ticks % 3 == 0)
		#):
		#return

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		return
	
	#var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	#if en_block_grid:
		#insert_random_block_by_global_event(wync_ctx, en_block_grid)
	#else:
		#Log.err(self, "coulnd't get singleton EnBlockGrid")

	var en_block_grid_delta = ECS.get_singleton_entity(self, "EnBlockGridDelta")
	if en_block_grid_delta:
		for i in range(2):
			insert_random_block_by_delta_event(wync_ctx, en_block_grid_delta)
		Log.out(self, "Generated new random event EVENT_DELTA_BLOCK_REPLACE")

	var en_block_grid_delta_predicted = ECS.get_singleton_entity(self, "EnBlockGridDeltaPredicted")
	if en_block_grid_delta_predicted:
		for i in range(2):
			insert_random_block_by_delta_event(wync_ctx, en_block_grid_delta_predicted)
		Log.out(self, "Generated new random event EVENT_DELTA_BLOCK_REPLACE")


func insert_random_block_by_global_event(wync_ctx: WyncCtx, en_block_grid: Entity):
	
	return
	"""
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

	# global event: commit and push

	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE, 2)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.VECTOR2, block_pos)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 1, WyncEntityProp.DATA_TYPE.INT, block_type)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)

	var err = WyncEventUtils.publish_global_event_as_server(wync_ctx, 0, event_id)
	if err != OK:
		Log.err(self, "Failed to push delta-sync-event err(%s)" % [err])

	WyncDeltaSyncUtils.merge_event_to_state_real_state(wync_ctx, prop_blocks_id, event_id)
	"""


func insert_random_block_by_delta_event(wync_ctx: WyncCtx, en_block_grid: Entity):

	var random_generator = RandomNumberGenerator.new()
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_actor = en_block_grid.get_component(CoActor.label) as CoActor
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid

	var block_pos = Vector2i(randi_range(0, CoBlockGrid.LENGTH-1), randi_range(0, CoBlockGrid.LENGTH-1))
	var block_type = random_generator.randi_range(CoBlockGrid.BLOCK.AIR, CoBlockGrid.BLOCK.DIAMOND)

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

	var err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(wync_ctx, prop_blocks_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks)
	if err != OK:
		Log.err(self, "Failed to push delta-sync-event err(%s)" % [err])

	WyncDeltaSyncUtils.merge_event_to_state_real_state(wync_ctx, prop_blocks_id, event_id)
