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
	var ctx = co_single_wync.ctx
	if not ctx.connected:
		return

	# Handle clients' events
	for wync_peer_id in range(1, ctx.peers.size()):
		run_client_events(node_ctx, ctx, wync_peer_id)
		
	# Handle server events
	run_server_events(node_ctx, ctx)


static func client_simulate_events(node_ctx: Node = null):
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = co_single_wync.ctx
	if not ctx.connected:
		return
	
	# Predict handling my own events
	run_client_events(node_ctx, ctx, ctx.my_peer_id)
	
	# Predict handling server events
	run_server_events(node_ctx, ctx)
	
	# as the grid: poll events from the channel 0 and execute them
	# NOTE: add iteration limit to avoid infinite _event loop_
	
	# NOTE: If we consume global events they might never be recorded... Or maybe they
	# can be recorded the moment they are submitted...
	#WyncEventUtils.global_event_consume(ctx, channel_id, event_id)
	
	# NOTE: events that generate other events can accumulate forever if not cleaned


static func run_client_events(node_ctx: Node, ctx: WyncCtx, client_wync_peer_id: int):
	# Handle server events
	
	var channel_id = 0
	var event_list: Array = ctx.peer_has_channel_has_events[client_wync_peer_id][channel_id]

	# NOTE: shouldn't this be ran from beggining to end?
	for i in range(event_list.size() -1, -1, -1):
		var event_id = event_list[i]
		if not ctx.events.has(event_id):
			continue
		var event = ctx.events[event_id]
		if event is not WyncEvent:
			continue
		event = event as WyncEvent
		
		#Log.out("Gonna execute this event %s" % [event_id], Log.TAG_DEBUG3)

		# handle it
		handle_events(node_ctx, event.data, client_wync_peer_id)
		
	event_list.clear()


static func run_server_events(node_ctx: Node, ctx: WyncCtx):
	# Handle server events
	
	var channel_id = 0
	var server_wync_peer_id = 0
	var event_list: Array = ctx.peer_has_channel_has_events[server_wync_peer_id][channel_id]
	while(event_list.size() > 0):
		var event_id = event_list[event_list.size() -1]
		if not ctx.events.has(event_id):
			continue
		var event = ctx.events[event_id]
		if event is not WyncEvent:
			WyncEventUtils.global_event_consume(ctx, server_wync_peer_id, channel_id, event_id)
			continue
		event = event as WyncEvent

		# handle it
		Log.out("event handling | handling server event %s" % [event_id], Log.TAG_GAME_EVENT)
		handle_events(node_ctx, event.data, server_wync_peer_id)
		WyncEventUtils.global_event_consume(ctx, server_wync_peer_id, channel_id, event_id)


static func run_local_entity_events(node_ctx: Node, entity: Entity):
	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = co_single_wync.ctx
	
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	
	# check if this event has an owner

	if not WyncUtils.prop_exists(ctx, co_wync_events.prop_id):
		Log.err("Couldn't find a Prop for this Event prop_id(%d)" % [co_wync_events.prop_id], Log.TAG_GAME_EVENT)
		return
	var peer_id = WyncUtils.prop_get_peer_owner(ctx, co_wync_events.prop_id)
	if peer_id == -1:
		Log.err("Couldn't find owner for prop_id(%d)" % [co_wync_events.prop_id], Log.TAG_GAME_EVENT)
		return
	# NOTE: Maybe check if the peer is alive
	
	
	var event_list = co_wync_events.events
	for i in range(event_list.size() -1, -1, -1):
		var event_id = event_list[i]
		if not ctx.events.has(event_id):
			Log.err("Couldn't find event(%s)" % [event_id], Log.TAG_GAME_EVENT)
			continue
		var event = ctx.events[event_id]
		if event is not WyncEvent:
			continue
		event = event as WyncEvent

		# handle it
		handle_events(node_ctx, event.data, peer_id)


static func handle_events(node_ctx: Node, event_data: WyncEvent.EventData, peer_id: int):
	Log.out("EVENT | debug1 | handling %d" % [event_data.event_type_id], Log.TAG_GAME_EVENT)
	match event_data.event_type_id:
		GameInfo.EVENT_PLAYER_BLOCK_BREAK:
			handle_event_player_block_break(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_BLOCK_PLACE:
			handle_event_player_block_place(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_BLOCK_BREAK_DELTA:
			handle_event_player_block_break_delta(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_BLOCK_PLACE_DELTA:
			handle_event_player_block_place_delta(node_ctx, event_data)
		GameInfo.EVENT_PLAYER_SHOOT:
			handle_event_player_shoot(node_ctx, event_data, peer_id)
		_:
			Log.err("event_type_id not recognized %s" % event_data.event_type_id, Log.TAG_GAME_EVENT)


static func handle_event_player_block_break(node_ctx: Node, event: WyncEvent.EventData):
	var data = event.event_data as GameInfo.EventPlayerBlockBreak
	var singleton_name = data.block_grid_id
	var block_pos = data.pos
	grid_block_break(node_ctx, singleton_name, block_pos)
	# NOTE: this could use more safety


static func handle_event_player_block_place(node_ctx: Node, event: WyncEvent.EventData):
	var data = event.event_data as GameInfo.EventPlayerBlockPlaceDelta
	var singleton_name = data.block_grid_id
	var block_pos = data.pos
	grid_block_place(node_ctx, singleton_name, block_pos)

	# NOTE: This event is a predicition of a Server Global event, so it has to be submitted
	# as a client-side PREDICTION for peer_id 0 
	
	## this event generates a secondary event BLOCK_BREAK breaking the block on the left
	block_pos.x -= 1
	if block_pos.x < 0:
		return

	var co_single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = co_single_wync.ctx

	var game_event = GameInfo.EventPlayerBlockBreak.new()
	game_event.block_grid_id = singleton_name
	game_event.pos = block_pos

	var event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_PLAYER_BLOCK_BREAK)
	WyncEventUtils.event_set_data(ctx, event_id, game_event)
	event_id = WyncEventUtils.event_wrap_up(ctx, event_id)
	
	# Out of the two ways to predict 'event generated events' here we're chosing _Option number 2_:
	# Generate new events as a prediction of the server's actions.
	WyncEventUtils.publish_global_event_as_server(ctx, 0, event_id)


static func handle_event_player_block_break_delta(node_ctx: Node, event: WyncEvent.EventData):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	var co_ticks = ctx.co_ticks

	var data = event.event_data as GameInfo.EventPlayerBlockBreakDelta
	var singleton_name = data.block_grid_id
	var block_pos = data.pos
	
	var en_block_grid = ECS.get_singleton_entity(node_ctx, singleton_name)
	if not en_block_grid:
		Log.err("coulnd't get singleton %s" % [singleton_name], Log.TAG_GAME_EVENT)
		return

	# user checks: is this event valid?

	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err("block_pos %s is invalid" % [block_pos], Log.TAG_GAME_EVENT)
		return

	# find the "blocks" property

	var co_actor = en_block_grid.get_component(CoActor.label) as CoActor
	var blocks_prop_id = WyncUtils.entity_get_prop_id(ctx, co_actor.id, "blocks")
	if blocks_prop_id == -1:
		Log.err("coulnd't find 'blocks' prop on singleton %s" % [singleton_name], Log.TAG_GAME_EVENT)
		return
	var blocks_prop = WyncUtils.get_prop(ctx, blocks_prop_id) as WyncEntityProp
	if not blocks_prop.relative_syncable:
		Log.err("singleton %s prop blocks id(%s) is not relative_syncable" % [singleton_name, blocks_prop_id], Log.TAG_GAME_EVENT)
		return

	# get the current block in order to "downgrade" it

	var block_new_stage = CoBlockGrid.BLOCK.AIR
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	if block_data.id > CoBlockGrid.BLOCK.AIR:
		block_new_stage = block_data.id -1

	# Commit a Delta Event here

	var game_event = GameInfo.EventDeltaBlockReplace.new()
	game_event.pos = block_pos
	game_event.block_id = block_new_stage

	var event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE)
	WyncEventUtils.event_set_data(ctx, event_id, game_event)
	event_id = WyncEventUtils.event_wrap_up(ctx, event_id)

	var err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
		ctx, blocks_prop_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks)
	if err != OK:
		Log.err("Failed to push delta-sync-event err(%s)" % [err], Log.TAG_DELTA_EVENT)

	var event_data = (ctx.events[event_id] as WyncEvent).data
	if WyncUtils.is_client(ctx):
		Log.outc(ctx, "debug_pred_delta_event | pred_tick(%s) predicted event (%s) %s" % [ctx.current_predicted_tick, event_id, HashUtils.object_to_dictionary(event_data)])

	# If this runs on the client it means prediction...

	WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, blocks_prop_id, event_id)


static func handle_event_player_block_place_delta(node_ctx: Node, event: WyncEvent.EventData):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	var co_ticks = ctx.co_ticks

	var data = event.event_data as GameInfo.EventPlayerBlockPlaceDelta
	var singleton_name = data.block_grid_id
	var block_pos = data.pos
	
	var en_block_grid = ECS.get_singleton_entity(node_ctx, singleton_name)
	if not en_block_grid:
		Log.err("coulnd't get singleton %s" % [singleton_name], Log.TAG_GAME_EVENT)
		return

	# user checks: is this event valid?

	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err("block_pos %s is invalid" % [block_pos], Log.TAG_GAME_EVENT)
		return

	# find the "blocks" property

	var co_actor = en_block_grid.get_component(CoActor.label) as CoActor
	var blocks_prop_id = WyncUtils.entity_get_prop_id(ctx, co_actor.id, "blocks")
	if blocks_prop_id == -1:
		Log.err("coulnd't find 'blocks' prop on singleton %s" % [singleton_name], Log.TAG_GAME_EVENT)
		return
	var blocks_prop = WyncUtils.get_prop(ctx, blocks_prop_id) as WyncEntityProp
	if not blocks_prop.relative_syncable:
		Log.err("singleton %s prop blocks id(%s) is not relative_syncable" % [singleton_name, blocks_prop_id], Log.TAG_GAME_EVENT)
		return

	# Commit a Delta Event here

	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	var block_new_stage = CoBlockGrid.BLOCK.DIAMOND 
	if block_data.id < CoBlockGrid.BLOCK.DIAMOND: # upgrade block
		block_new_stage = block_data.id +1

	var game_event = GameInfo.EventDeltaBlockReplace.new()
	game_event.pos = block_pos
	game_event.block_id = block_new_stage

	var event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE)
	WyncEventUtils.event_set_data(ctx, event_id, game_event)
	event_id = WyncEventUtils.event_wrap_up(ctx, event_id)

	var err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
		ctx, blocks_prop_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks)
	if err != OK:
		Log.err("Failed to push delta-sync-event err(%s)" % [err], Log.TAG_DELTA_EVENT)
	WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, blocks_prop_id, event_id)

	var event_data = (ctx.events[event_id] as WyncEvent).data
	if WyncUtils.is_client(ctx):
		Log.outc(ctx, "debug_pred_delta_event | pred_tick(%s) predicted event (%s) %s" % [ctx.current_predicted_tick, event_id, HashUtils.object_to_dictionary(event_data)])

	# purposefully misspredict
	if WyncUtils.is_client(ctx):
		var initial_y = block_pos.y
		for i in range(1, 2):
			# secondary break event
			block_pos.y = initial_y - i
			if block_pos.y < 0:
				return

			block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
			block_new_stage = CoBlockGrid.BLOCK.AIR
			if block_data.id > block_new_stage: # downgrade block
				block_new_stage = block_data.id -1

			game_event = GameInfo.EventDeltaBlockReplace.new()
			game_event.pos = block_pos
			game_event.block_id = block_new_stage

			event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE)
			WyncEventUtils.event_set_data(ctx, event_id, game_event)
			event_id = WyncEventUtils.event_wrap_up(ctx, event_id)

			err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
				ctx, blocks_prop_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks)
			if err != OK:
				Log.err("Failed to push delta-sync-event err(%s)" % [err], Log.TAG_DELTA_EVENT)
			WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, blocks_prop_id, event_id)

			event_data = (ctx.events[event_id] as WyncEvent).data
			if WyncUtils.is_client(ctx):
				Log.outc(ctx, "debug_pred_delta_event | pred_tick(%s) predicted event (%s) %s" % [ctx.current_predicted_tick, event_id, HashUtils.object_to_dictionary(event_data)])
		return

	# secondary break event

	block_pos.x -= 1
	if block_pos.x < 0:
		return

	block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_new_stage = CoBlockGrid.BLOCK.AIR
	if block_data.id > block_new_stage: # downgrade block
		block_new_stage = block_data.id -1

	game_event = GameInfo.EventDeltaBlockReplace.new()
	game_event.pos = block_pos
	game_event.block_id = block_new_stage

	event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE)
	WyncEventUtils.event_set_data(ctx, event_id, game_event)
	event_id = WyncEventUtils.event_wrap_up(ctx, event_id)

	err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
		ctx, blocks_prop_id, GameInfo.EVENT_DELTA_BLOCK_REPLACE, event_id, co_ticks)
	if err != OK:
		Log.err("Failed to push delta-sync-event err(%s)" % [err], Log.TAG_DELTA_EVENT)
	WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, blocks_prop_id, event_id)

	event_data = (ctx.events[event_id] as WyncEvent).data
	if WyncUtils.is_client(ctx):
		Log.outc(ctx, "debug_pred_delta_event | pred_tick(%s) predicted event (%s) %s" % [ctx.current_predicted_tick, event_id, HashUtils.object_to_dictionary(event_data)])


# server only function
static func handle_event_player_shoot(node_ctx: Node, event: WyncEvent.EventData, peer_id: int):
	
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	var co_ticks = ctx.co_ticks
	
	# NOTE: peer_id shouldn't be 0 (the server's)
	var client_info = ctx.client_has_info[peer_id] as WyncClientInfo
	
	var lerp_ms: int = client_info.lerp_ms
	var data = event.event_data as GameInfo.EventPlayerShoot
	var tick_left: int = data.last_tick_rendered_left
	var lerp_delta: float = data.lerp_delta
	
	# TODO: Lerp delta is not in this format
	if lerp_delta < 0 || lerp_delta > 1000:
		Log.errc(ctx, "TIMEWARP | lerp_delta is outside [0, 1] (%s)" % [lerp_delta], Log.TAG_TIMEWARP)
		return

	# NOTE: We can provide some modes of security, this helps against cheaters:
	# * (1) Low. No limit, current implementation
	# * (2) Middle. Allow ticks in the range of the _prob prop rate_
	# * (1) High. Only allow ranges of 1 tick (the small range defined by the client's: latency + lerp_ms + last_packet_sent)
	if ((tick_left <= co_ticks.ticks - ctx.max_tick_history) ||
		(tick_left > co_ticks.ticks)
		):
		Log.errc(ctx, "timewarp | tick_left out of range (%s)" % [tick_left], Log.TAG_TIMEWARP)
		return

	
	Log.outc(ctx, "Client shoots at tick_left %d | lerp_delta %s | lerp_ms %s | tick_diff %s" % [ tick_left, lerp_delta, lerp_ms, co_ticks.ticks - tick_left ], Log.TAG_TIMEWARP)
	

	# ------------------------------------------------------------
	# time warp: reset all timewarpable props to a previous state, whilst saving their current state

	var space := node_ctx.get_viewport().world_2d.space
	
	# 1. save current state
	# TODO: update saved state _only_ for selected props
	
	SyWyncStateExtractor.extract_data_to_tick(ctx, co_ticks, co_ticks.ticks)
	
	var prop_ids_to_timewarp: Array[int] = []
	for prop_id: int in ctx.active_prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop_id != 3: # ????
			continue 
		if prop == null:
			continue
		if not prop.timewarpable:
			continue

		prop_ids_to_timewarp.append(prop_id)

	# 2. set previous state
	
	SyWyncLerp.confirmed_states_set_to_tick_interpolated(ctx, prop_ids_to_timewarp, tick_left, lerp_delta, co_ticks)

	# show debug trail
		
	for prop_id: int in prop_ids_to_timewarp:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		DebugPlayerTrail.spawn(node_ctx, prop.interpolated_state, 0.3, 2.5)
	
	# integrate physics

	Log.outc(ctx, "entities to integrate state are %s" % [ctx.tracked_entities.keys()], Log.TAG_TIMEWARP)
	SyWyncLatestValue.integrate_state(ctx, ctx.tracked_entities.keys())
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)

	# 3. do my physics checks

	var world_id = ECS.find_world_up(node_ctx).get_instance_id()
	var sy_shoot_weapon_entities = ECS.get_system_entities(world_id, SyShootWeapon.label)
	for entity in sy_shoot_weapon_entities:
		Log.outc(ctx, "event,shoot | will process SyShootWeapon on entity %s" % [entity], Log.TAG_TIMEWARP)
		SyShootWeapon.simulate_shoot_weapon(node_ctx, entity)
	
	# 4. restore original state

	SyWyncLerp.confirmed_states_set_to_tick(ctx, prop_ids_to_timewarp, co_ticks.ticks, co_ticks)

	# integrate physics

	SyWyncLatestValue.integrate_state(ctx, ctx.tracked_entities.keys())
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)



# --------------------------------------------------------------------------------
# Game util functions

	
static func grid_block_break(node_ctx: Node, entity_block_grid_name: String, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, entity_block_grid_name)
	if not en_block_grid:
		Log.err("coulnd't get singleton %s" % [entity_block_grid_name], Log.TAG_GAME_EVENT)
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err("block_pos %s is invalid" % [block_pos], Log.TAG_GAME_EVENT)
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.AIR


static func grid_block_place(node_ctx: Node, entity_block_grid_name: String, block_pos: Vector2i):
	var en_block_grid = ECS.get_singleton_entity(node_ctx, entity_block_grid_name)
	if not en_block_grid:
		Log.err("coulnd't get singleton %s" % [entity_block_grid_name], Log.TAG_GAME_EVENT)
		return
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	
	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err("block_pos %s is invalid" % [block_pos], Log.TAG_GAME_EVENT)
		return
	
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = CoBlockGrid.BLOCK.STONE
