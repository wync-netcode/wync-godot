class_name SyActorEvents
extends System
const label: StringName = StringName("SyActorEvents")


func _ready():
	components = [
		CoActor.label,
		CoWyncEvents.label
	]
	super()


func on_process(entities: Array, _data, _delta: float, node_ctx: Node = null):
	
	node_ctx = self if node_ctx == null else node_ctx
	server_simulate_events(node_ctx)
	
	# events relative to the entities
	for entity in entities:
		run_local_entity_events(node_ctx, entity)


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
		handle_events(node_ctx, event.data, client_wync_peer_id)
		
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
		handle_events(node_ctx, event.data, server_wync_peer_id)
		WyncEventUtils.global_event_consume(wync_ctx, server_wync_peer_id, channel_id, event_id)


static func run_local_entity_events(node_ctx: Node, entity: Entity):
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	
	# check if this event has an owner

	if not WyncUtils.prop_exists(wync_ctx, co_wync_events.prop_id):
		Log.err(node_ctx, "Couldn't find a Prop for this Event prop_id(%d)" % [co_wync_events.prop_id])
		return
	var peer_id = WyncUtils.prop_get_peer_owner(wync_ctx, co_wync_events.prop_id)
	if peer_id == -1:
		Log.err(node_ctx, "Couldn't find owner for prop_id(%d)" % [co_wync_events.prop_id])
		return
	# NOTE: Maybe check if the peer is alive
	
	
	var event_list = co_wync_events.events
	for i in range(event_list.size() -1, -1, -1):
		var event_id = event_list[i]
		if not wync_ctx.events.has(event_id):
			continue
		var event = wync_ctx.events[event_id]
		if event is not WyncEvent:
			continue
		event = event as WyncEvent

		# handle it
		handle_events(node_ctx, event.data, peer_id)


static func handle_events(node_ctx: Node, event_data: WyncEvent.EventData, peer_id: int):
	Log.out(node_ctx, "EVENT | handling %d" % [event_data.event_type_id])
	match event_data.event_type_id:
		GameInfo.EVENT_PLAYER_BLOCK_BREAK:
			handle_event_player_block_break(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_BLOCK_PLACE:
			handle_event_player_block_place(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_SHOOT:
			handle_event_player_shoot(node_ctx, event_data, peer_id)
		_:
			Log.err(node_ctx, "event_type_id not recognized %s" % event_data.event_type_id)


static func handle_event_player_block_break(node_ctx: Node, event: WyncEvent.EventData):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_break(node_ctx, "EnBlockGrid", block_pos)
	# NOTE: this could use more safety


static func handle_event_player_block_place(node_ctx: Node, event: WyncEvent.EventData):
	var block_pos = event.arg_data[0] as Vector2i
	grid_block_place(node_ctx, "EnBlockGrid", block_pos)

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
	WyncEventUtils.publish_global_event_as_server(wync_ctx, 0, event_id)

	
static func grid_block_break(node_ctx: Node, entity_block_grid_name: String, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, entity_block_grid_name)
	if not en_block_grid:
		Log.err(node_ctx, "coulnd't get singleton %s" % [entity_block_grid_name])
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(node_ctx, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.AIR


static func grid_block_place(node_ctx: Node, entity_block_grid_name: String, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, entity_block_grid_name)
	if not en_block_grid:
		Log.err(node_ctx, "coulnd't get singleton %s" % [entity_block_grid_name])
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err(node_ctx, "block_pos %s is invalid" % [block_pos])
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.STONE


# server only function
static func handle_event_player_shoot(node_ctx: Node, event: WyncEvent.EventData, peer_id: int):
	
	var co_ticks = ECS.get_singleton_component(node_ctx, CoTicks.label) as CoTicks
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_single_wync.ctx
	
	# NOTE: peer_id shouldn't be 0 (the server's)
	var client_info = wync_ctx.client_has_info[peer_id] as WyncClientInfo
	
	var lerp_ms: int = client_info.lerp_ms
	var tick_left: int = event.arg_data[0] as int
	var lerp_delta: float = event.arg_data[1] as float
	
	# TODO: Lerp delta is not in this format
	if lerp_delta < 0 || lerp_delta > 1000:
		Log.err(node_ctx, "TIMEWARP | lerp_delta is outside [0, 1] (%s)" % [lerp_delta])
		return

	# TODO: limit the tick to the small range defined by the client's: latency + lerp_ms + last_packet_sent
	if ((tick_left <= co_ticks.ticks - wync_ctx.max_tick_history) ||
		(tick_left > co_ticks.ticks)
		):
		Log.err(node_ctx, "timewarp | tick_left out of range (%s)" % [tick_left])
		return

	
	Log.out(node_ctx, "Client shoots at tick_left %d | lerp_delta %s | lerp_ms %s | tick_diff %s" % [ tick_left, lerp_delta, lerp_ms, co_ticks.ticks - tick_left ])
	

	# ------------------------------------------------------------
	# time warp: reset all timewarpable props to a previous state, whilst saving their current state

	var space := node_ctx.get_viewport().world_2d.space
	
	# 1. save current state
	# TODO: update saved state _only_ for selected props
	
	SyWyncStateExtractor.extract_data_to_tick(wync_ctx, co_ticks, co_ticks.ticks)
	
	var prop_ids_to_timewarp: Array[int] = []
	for prop_id: int in range(wync_ctx.props.size()):
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop_id != 2:
			continue 
		if prop == null:
			continue
		if not prop.timewarpable:
			continue

		prop_ids_to_timewarp.append(prop_id)

	# 2. set previous state
	
	SyWyncLerp.confirmed_states_set_to_tick_interpolated(wync_ctx, prop_ids_to_timewarp, tick_left, lerp_delta, co_ticks)

	# show debug trail
		
	for prop_id: int in prop_ids_to_timewarp:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		DebugPlayerTrail.spawn(node_ctx, prop.interpolated_state, 0.8, 2)
	
	# integrate physics

	Log.out(node_ctx, "entities to integrate state are %s" % [wync_ctx.tracked_entities.keys()])
	SyWyncLatestValue.integrate_state(wync_ctx, wync_ctx.tracked_entities.keys())
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)

	# 3. do my physics checks

	var world_id = ECS.find_world_up(node_ctx).get_instance_id()
	var sy_shoot_weapon_entities = ECS.get_system_entities(world_id, SyShootWeapon.label)
	for entity in sy_shoot_weapon_entities:
		Log.out(node_ctx, "event,shoot | will process SyShootWeapon on entity %s" % [entity])
		SyShootWeapon.simulate_shoot_weapon(node_ctx, entity)
	
	# 4. restore original state

	SyWyncLerp.confirmed_states_set_to_tick(wync_ctx, prop_ids_to_timewarp, co_ticks.ticks, co_ticks)

	# integrate physics

	SyWyncLatestValue.integrate_state(wync_ctx, wync_ctx.tracked_entities.keys())
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)
