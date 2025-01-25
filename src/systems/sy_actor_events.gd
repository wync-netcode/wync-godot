class_name SyActorEvents
extends System
const label: StringName = StringName("SyActorEvents")


func _ready():
	components = [
		CoActor.label,
		CoWyncEvents.label
	]
	super()


func on_process(entities: Array, _data, _delta: float):
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	
	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
		
		for event_id in co_wync_events.events:
			
			# print events for now
			Log.out(self, "Entity %d did event %s" % [co_actor.id, event_id])
			
			# get event data
			if not wync_ctx.events.has(event_id):
				Log.err(self, "NO EVENT DATA for event id %s" % event_id)
				continue
			var event_data = wync_ctx.events[event_id] as WyncEvent
			
			Log.out(self, "event_id %s event_type_id %s" % [event_id, event_data.event_type_id])
			
			match event_data.event_type_id:
				GameInfo.EVENT_PLAYER_BLOCK_BREAK:
					handle_event_player_block_break(event_data)
				GameInfo.EVENT_PLAYER_BLOCK_PLACE:
					handle_event_player_block_place(event_data)
				_:
					Log.err(self, "event_type_id not recognized %s" % event_data.event_type_id)


func handle_event_player_block_break(event: WyncEvent):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_break(block_pos)
	# NOTE: this could use more safety


func handle_event_player_block_place(event: WyncEvent):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_place(block_pos)
	
	
func grid_block_break(block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	if not en_block_grid:
		Log.err(self, "coulnd't get singleton EnBlockGrid")
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(self, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.AIR


func grid_block_place(block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	if not en_block_grid:
		Log.err(self, "coulnd't get singleton EnBlockGrid")
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(self, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.STONE
	
	
