class_name SyActorEvents
extends System
const label: StringName = StringName("SyActorEvents")


func _ready():
	components = [
		CoActor.label,
		CoWyncEvents.label
	]
	super()


func on_process(_entities: Array, _data, _delta: float, node_ctx: Node = null):
	
	node_ctx = self if node_ctx == null else node_ctx
	server_simulate_events(node_ctx)
	
	"""
	# TODO: Put this in another place for entity-local events
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
			handle_events(event_data)
	"""

static func server_simulate_events(node_ctx: Node = null):
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	var channel_id = 0

	# Handle clients' events
	for wync_peer_id in range(1, wync_ctx.peers.size()):
		run_client_events(node_ctx, wync_ctx, wync_peer_id)
		
	# Handle server events
	run_server_events(node_ctx, wync_ctx)


static func client_simulate_events(node_ctx: Node = null):
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	
	# Predict handling my own events
	run_client_events(node_ctx, wync_ctx, wync_ctx.my_peer_id)
	
	# Predict handling server events
	run_server_events(node_ctx, wync_ctx)
	
	# as the grid: poll events from the channel 0 and execute them
	# NOTE: add iteration limit to avoid infinite _event loop_

	# NOTE: on client: iterate through MY events
	# on server: iterate through EVERY CLIENT'S events
	
	# NOTE: If we consume global events they might never be recorded... Or maybe they
	# can be recorded the moment they are submitted...
	#WyncEventUtils.global_event_consume(wync_ctx, channel_id, event_id)
	
	# NOTE: events that generate other events can accumulate forever if not cleaned


static func run_client_events(node_ctx: Node, wync_ctx: WyncCtx, client_wync_peer_id: int):
	# Handle server events
	
	var channel_id = 0
	var event_list: Array = wync_ctx.peer_has_channel_has_events[client_wync_peer_id][channel_id]
	for i in range(event_list.size() -1, -1, -1):
		var event_id = event_list[i]
		if not wync_ctx.events.has(event_id):
			continue
		var event = wync_ctx.events[event_id]
		if event is not WyncEvent:
			continue
		event = event as WyncEvent

		# handle it
		handle_events(node_ctx, event.data)
		
	event_list.clear()


static func run_server_events(node_ctx: Node, wync_ctx: WyncCtx):
	# Handle server events
	
	var channel_id = 0
	var server_wync_peer_id = 0
	var event_list: Array = wync_ctx.peer_has_channel_has_events[server_wync_peer_id][channel_id]
	while(event_list.size() > 0):
		var event_id = event_list[event_list.size() -1]
		if not wync_ctx.events.has(event_id):
			continue
		var event = wync_ctx.events[event_id]
		if event is not WyncEvent:
			WyncEventUtils.global_event_consume(wync_ctx, server_wync_peer_id, channel_id, event_id)
			continue
		event = event as WyncEvent

		# handle it
		handle_events(node_ctx, event.data)
		WyncEventUtils.global_event_consume(wync_ctx, server_wync_peer_id, channel_id, event_id)


static func handle_events(node_ctx: Node, event_data: WyncEvent.EventData):
	match event_data.event_type_id:
		GameInfo.EVENT_PLAYER_BLOCK_BREAK:
			handle_event_player_block_break(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_BLOCK_PLACE:
			handle_event_player_block_place(node_ctx, event_data)
		_:
			Log.err(node_ctx, "event_type_id not recognized %s" % event_data.event_type_id)


static func handle_event_player_block_break(node_ctx: Node, event: WyncEvent.EventData):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_break(node_ctx, block_pos)
	# NOTE: this could use more safety


static func handle_event_player_block_place(node_ctx: Node, event: WyncEvent.EventData):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_place(node_ctx, block_pos)

	# NOTE: This event is a predicition of a Server Global event, so it has to be submitted
	# as a client-side PREDICTION for peer_id 0 
	
	## this event generates a secondary event BLOCK_BREAK breaking the block on the left
	block_pos.x -= 1
	if block_pos.x < 0:
		return

	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx

	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, GameInfo.EVENT_PLAYER_BLOCK_BREAK, 1)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.VECTOR2, block_pos)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)
	
	# Out of the two ways to predict 'event generated events' here we're chosing _Option number 2_:
	# Generate new events as a prediction of the server's actions.
	WyncEventUtils.publish_globa_event_as_server(wync_ctx, 0, event_id)
	
	
static func grid_block_break(node_ctx: Node, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, "EnBlockGrid")
	if not en_block_grid:
		Log.err(node_ctx, "coulnd't get singleton EnBlockGrid")
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(node_ctx, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.AIR


static func grid_block_place(node_ctx: Node, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, "EnBlockGrid")
	if not en_block_grid:
		Log.err(node_ctx, "coulnd't get singleton EnBlockGrid")
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(node_ctx, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.STONE
