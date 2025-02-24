extends System
class_name SyDrawBlockGridDelta
const label: StringName = StringName("SyDrawBlockGridDelta")

const TILE_LENGTH_PIXELS = 30


## This system runs ONE time AFTER the physics frame has ended, but not EVERY _draw frame_. 
## As a result, events generated here must be buffered at the beginning of the next physics frame


func _ready():
	components = [CoBlockGrid.label]
	super()


func _draw() -> void:
	var world = ECS.find_world_up(self)
	var world_id = world.get_instance_id()
	
	if not ECS.world_systems.has(world_id) ||\
		not ECS.world_systems[world_id].has(label):
		return
	else:
		var _system = ECS.world_systems[world_id][label]
		if _system == null || !_system.enabled:
			return
	
	var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGridDelta")
	if en_block_grid:
		draw_block_grid(en_block_grid, "EnBlockGridDelta", Vector2i(3, 1))
	en_block_grid = ECS.get_singleton_entity(self, "EnBlockGridDeltaPredicted")
	if en_block_grid:
		draw_block_grid(en_block_grid, "EnBlockGridDeltaPredicted", Vector2i(3, 2))


func draw_block_grid(entity: Entity, singleton_grid_name: String, offset: Vector2i):
	var node2d = self as Node as Node2D
	var block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	if !block_grid:
		return
	var single_world = ECS.get_singleton_component(self, CoSingleWorld.label) as CoSingleWorld
	var x_offset = (offset.x + single_world.world_id) * ((block_grid.LENGTH + 1) * TILE_LENGTH_PIXELS)
	var y_offset = offset.y * ((block_grid.LENGTH + 1) * TILE_LENGTH_PIXELS)
	
	for i in range(block_grid.LENGTH):
		for j in range(block_grid.LENGTH):
			# tile
			var block_rect = Rect2(
				i * TILE_LENGTH_PIXELS + x_offset,
				j * TILE_LENGTH_PIXELS + y_offset,
				TILE_LENGTH_PIXELS,
				TILE_LENGTH_PIXELS
			)
			node2d.draw_rect(block_rect, Color.BLACK, false)
			
			# sprite
			var sprite_rect = Rect2(block_rect)
			sprite_rect.position += Vector2.ONE * 4
			sprite_rect.size -= Vector2.ONE * 8
			
			var block = block_grid.blocks[i][j] as CoBlockGrid.BlockData
			SyDrawBlockGrid.draw_block(node2d, sprite_rect, block)
			
			# client interaction
			if !is_client_application():
				continue
			
			var mouse = node2d.get_local_mouse_position()
			#Log.out(self, "mouse pos %s , rect pos %s" % [mouse, block_rect.position])
			if block_rect.has_point(mouse):
				var color = Color.WHITE
				color.a = 0.3
				node2d.draw_rect(block_rect, color, true)
				
				var event = GameInfo.EVENT_NONE
				if Input.is_action_just_pressed("p1_mouse1"):
					event = GameInfo.EVENT_PLAYER_BLOCK_BREAK_DELTA
				elif Input.is_action_just_pressed("p1_mouse2"):
					event = GameInfo.EVENT_PLAYER_BLOCK_PLACE_DELTA
				if event != GameInfo.EVENT_NONE:
					color = Color.RED
					color.a = 0.5
					node2d.draw_rect(block_rect, color, true)
					Log.out("debug1 | EVENT MOUSE CLICK %s" % Vector2i(i,j), Log.TAG_GAME_EVENT)
					
					generate_block_grid_event(singleton_grid_name, event, Vector2i(i,j))


func on_process(_entities, _data, _delta):
	if (self as Node) is Node2D:
		(self as Node as Node2D).queue_redraw()


func is_client_application() -> bool:
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	return single_client != null


func generate_block_grid_event(
	block_grid_id: String,
	event_type_id: int,
	event_data # : any
	):
	# NOTE alternative approach:
	# from the props I have ownership, which one is of type EVENT?
	# append the new event to that...
	# NOTE current approach:
	# Feed event into my prop array of events
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_ticks = wync_ctx.co_ticks
	
	# FIXME: harcoded entity with id 0
	var player_entity_id = 0
	
	# get the player entity that contains my custom events
	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		Log.err("Can't find EnSingleActors", Log.TAG_GAME_EVENT)
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors
	var player_entity = co_actors.actors[player_entity_id]
	if not player_entity:
		Log.err("Can't find player_entity", Log.TAG_GAME_EVENT)
		return
	
	# get the CoWyncEvent component
	var co_wync_events = player_entity.get_component(CoWyncEvents.label) as CoWyncEvents
	if not co_wync_events:
		Log.err("Can't find co_wync_events", Log.TAG_GAME_EVENT)
		return
	
	# first register the event to Wync
	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, event_type_id, 2)
	if event_id == null: return
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.STRING, block_grid_id)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 1, WyncEntityProp.DATA_TYPE.VECTOR2, event_data)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)
	if (event_id == null):
		Log.err("Error WyncEventUtils.event_wrap_up(wync_ctx, event_id) got(%s)" % [event_id], Log.TAG_GAME_EVENT)
		return
	
	var _event = wync_ctx.events[event_id] as WyncEvent
	if _event:
		Log.out("TESTING event id(%s) hash: event_data %s arg_count %s arg_data %s" % [event_id, event_data, _event.data.arg_count, _event.data.arg_data], Log.TAG_GAME_EVENT)
		Log.out("event %s hash %s" % [_event, HashUtils.hash_any(_event.data.arg_data)], Log.TAG_GAME_EVENT)
	
	# save the event id to component
	#co_wync_events.events.append(event_id)

	# now that we're commiting to this event, let's publish it
	WyncEventUtils.publish_global_event_as_client(
		wync_ctx, 0, event_id
	)
	
	var co_predict_data = wync_ctx.co_predict_data
	Log.out("debug1 lo_ticks(%s) ser_ticks(%s) target(%s) co_wync_events.events %s:%s:%s" % [co_ticks.ticks, co_ticks.server_ticks, co_predict_data.target_tick, co_wync_events, co_wync_events.events.size(), co_wync_events.events], Log.TAG_GAME_EVENT)
