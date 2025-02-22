extends System
class_name SyDrawBlockGrid
const label: StringName = StringName("SyDrawBlockGrid")

const TILE_LENGTH_PIXELS = 30


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
	
	var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	if en_block_grid:
		draw_block_grid(en_block_grid, "EnBlockGrid", Vector2i(3, 0))


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
			match block.id:
				CoBlockGrid.BLOCK.AIR:
					node2d.draw_line(sprite_rect.position, sprite_rect.end, Color.AQUAMARINE, 3)
				CoBlockGrid.BLOCK.STONE:
					node2d.draw_rect(sprite_rect, Color.DIM_GRAY, true)
					node2d.draw_rect(sprite_rect, Color.BLACK, false)
				CoBlockGrid.BLOCK.TNT:
					node2d.draw_rect(sprite_rect, Color.DARK_RED, true)
					var tnt_stripe_rect = Rect2(sprite_rect)
					tnt_stripe_rect.position.y += tnt_stripe_rect.size.y / 3
					tnt_stripe_rect.size.y /= 3
					node2d.draw_rect(tnt_stripe_rect, Color.WHITE, true)
					node2d.draw_rect(sprite_rect, Color.BLACK, false)
					pass
			
			# on fire
			if block.on_fire:
				var fire_rect = Rect2(sprite_rect)
				fire_rect.position.x += fire_rect.size.x * 0.7
				fire_rect.size *= 1.0 - 0.7
				node2d.draw_rect(fire_rect, Color.ORANGE, true)
			
			# client interaction
			if !is_client_application():
				continue
			
			var mouse = node2d.get_local_mouse_position()
			#Log.out(self, "mouse pos %s , rect pos %s" % [mouse, block_rect.position])
			if block_rect.has_point(mouse):
				var color = Color.WHITE
				color.a = 0.5
				node2d.draw_rect(block_rect, color, true)
				
				var event = GameInfo.EVENT_NONE
				if Input.is_action_just_pressed("p1_mouse1"):
					event = GameInfo.EVENT_PLAYER_BLOCK_BREAK
				elif Input.is_action_just_pressed("p1_mouse2"):
					event = GameInfo.EVENT_PLAYER_BLOCK_PLACE
				if event != GameInfo.EVENT_NONE:
					color = Color.RED
					color.a = 0.5
					node2d.draw_rect(block_rect, color, true)
					Log.out(self, "EVENT MOUSE CLICK %s" % Vector2i(i,j))
					
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
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# FIXME: harcoded entity with id 0
	var player_entity_id = 0
	
	# get the player entity that contains my custom events
	var single_actors = ECS.get_singleton_entity(self, "EnSingleActors")
	if not single_actors:
		Log.err(self, "Can't find EnSingleActors")
		return
	var co_actors = single_actors.get_component(CoSingleActors.label) as CoSingleActors
	var player_entity = co_actors.actors[player_entity_id]
	if not player_entity:
		Log.err(self, "Can't find player_entity")
		return
	
	# get the CoWyncEvent component
	var co_wync_events = player_entity.get_component(CoWyncEvents.label) as CoWyncEvents
	if not co_wync_events:
		Log.err(self, "Can't find co_wync_events")
		return
	
	# first register the event to Wync
	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, event_type_id, 2)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.STRING, block_grid_id)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 1, WyncEntityProp.DATA_TYPE.VECTOR2, event_data)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)
	if (event_id < 0):
		Log.err(self, "Error WyncEventUtils.event_wrap_up(wync_ctx, event_id)")
		return
	
	var _event = wync_ctx.events[event_id] as WyncEvent
	if _event:
		Log.out(self, "TESTING event id(%s) hash: event_data %s arg_count %s arg_data %s" % [event_id, event_data, _event.data.arg_count, _event.data.arg_data])
		Log.out(self, "event %s hash %s" % [_event, HashUtils.hash_any(_event.data.arg_data)])
	
	# save the event id to component
	#co_wync_events.events.append(event_id)

	# now that we're commiting to this event, let's publish it
	WyncEventUtils.publish_global_event_as_client(
		wync_ctx, 0, event_id
	)
	
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	Log.out(self, "ticks(%s|%s) co_wync_events.events %s:%s:%s" % [co_ticks.ticks, co_predict_data.target_tick, co_wync_events, co_wync_events.events.size(), co_wync_events.events])
