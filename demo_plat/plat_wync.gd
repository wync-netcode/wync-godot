class_name PlatWync


static func setup_server(ctx: WyncCtx):
	ctx.common.ticks = 0
	WyncFlow.server_setup(ctx)
	WyncClock.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	setup_lerp_types(ctx)
	setup_blueprints(ctx)


static func setup_client(ctx: WyncCtx):
	ctx.common.ticks = 200
	WyncFlow.client_init(ctx)
	
	WyncClock.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	WyncClock.clock_set_debug_time_offset(ctx, 1000)

	# set server tick rate and lerp_ms

	#var server_tick_rate: float = ctx.physic_ticks_per_second 
	var server_tick_rate: float = ctx.common.physic_ticks_per_second / 2.0
	#var server_tick_rate: float = ctx.physic_ticks_per_second / 8.0
	#var server_tick_rate: float = ctx.physic_ticks_per_second / 16.0

	#var desired_lerp: float = ceil((1000.0 / server_tick_rate) * 5) # 6 ticks in the past
	#WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, desired_lerp)
	WyncLerp.wync_client_set_lerp_ms(ctx, server_tick_rate, 0)
	WyncLerp.wync_client_set_max_lerp_factor_symmetric(ctx, 3.5)

	setup_lerp_types(ctx)
	setup_blueprints(ctx)


static func setup_connect_client(gs: Plat.GameState):
	var ctx := gs.wctx
	for nete_peer_id: int in ctx.co_throttling.out_peer_pending_to_setup:

		#pass
		# get wync_peer_id
		var wync_peer_id = WyncJoin.is_peer_registered(ctx, nete_peer_id)
		assert(wync_peer_id != -1)

		# spawn some entity
		var actor_id = PlatPublic.spawn_player_server(gs, PlatUtils.GRID_CORD(17, 6))

		# setup actor with wync
		setup_sync_for_player_actor(gs, actor_id)

		# give client authority over prop
		for prop_name_id: String in ["input"]:
			var prop_id = WyncTrack.entity_get_prop_id(ctx, actor_id, prop_name_id)
			WyncInput.prop_set_client_owner(ctx, prop_id, wync_peer_id)

		# Note: In bigger games with different levels you might set this up also on level change
		setup_new_client_level_props(gs, wync_peer_id)

		# assign newly created entity to 'nete peer'
		for peer: Plat.Server.Peer in gs.net.server.peers:
			if peer.peer_id == nete_peer_id:
				peer.player_actor_id = actor_id
				peer.already_setup = true


	WyncJoin.clear_peers_pending_to_setup(ctx)


# setup entities that the client should already have present
static func setup_new_client_level_props(gs: Plat.GameState, wync_peer_id: int):
	return

	# chunk entities should be present
	#for i: int in range(Plat.CHUNK_AMOUNT):
		#var chunk := gs.chunks[i]
		#if chunk == null:
			#continue
		#WyncThrottle.wync_add_local_existing_entity(gs.wctx, wync_peer_id, chunk.actor_id)


static func setup_lerp_types(ctx: WyncCtx):
	WyncLerp.wync_register_lerp_type(
		ctx, Plat.LERP_TYPE_FLOAT,
		func (a: float, b: float, weight: float): return lerp(a, b, weight)
	)
	WyncLerp.wync_register_lerp_type(
		ctx, Plat.LERP_TYPE_VECTOR2,
		func (a: Vector2, b: Vector2, weight: float): return lerp(a, b, weight)
	)


static func setup_blueprints(ctx: WyncCtx):
	# setup relative synchronization blueprints

	var blueprint_id = WyncDeltaSyncUtils.create_delta_blueprint(ctx)
	WyncDeltaSyncUtils.delta_blueprint_register_event(
		ctx,
		blueprint_id,
		Plat.EVENT_DELTA_BLOCK_REPLACE,
		blueprint_handle_event_delta_block_replace
	)
	Plat.BLUEPRINT_ID_BLOCK_GRID_DELTA = blueprint_id


static func blueprint_handle_event_delta_block_replace \
	(user_ctx: Variant, event: WyncCtx.WyncEventEventData, requires_undo: bool, ctx: WyncCtx) -> Array[int]:
	
	# TODO: maybe check event integrity before casting
	var chunk := user_ctx as Plat.Chunk
	var event_data := event.event_data as Plat.EventDeltaBlockReplace
	var block_pos = event_data.pos

	var block = chunk.blocks[block_pos.x][block_pos.y] as Plat.Block
	var event_id = -1

	# create undo event
	if requires_undo:
		var prev_block_type = block.type

		var undo_event = Plat.EventDeltaBlockReplace.new()
		undo_event.pos = block_pos
		undo_event.block_type = prev_block_type
		event_id = WyncEventUtils.new_event_wrap_up(ctx, Plat.EVENT_DELTA_BLOCK_REPLACE, undo_event)
		assert(event_id != null)

	block.type = event_data.block_type
	return [OK, event_id]


static func setup_sync_for_ball_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var wctx = gs.wctx
	var actor := PlatPublic.get_actor(gs, actor_id)
	var ball_instance := gs.balls[actor.instance_id]

	if WyncTrack.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_BALL) != OK:
		return

	var pos_prop_id = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncCtx.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		ball_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Ball).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Ball).position = pos,
	)
	WyncPropUtils.prop_enable_interpolation(
		wctx, pos_prop_id, Plat.LERP_TYPE_VECTOR2
	)

	if not wctx.common.is_client: # server
		WyncTimeWarp.prop_set_timewarpable(wctx, pos_prop_id) 

	#if WyncTrack.is_client(wctx):
		
		## setup extrapolation

		##if co_actor.id % 2 == 0:
			##WyncTrack.prop_set_predict(wctx, pos_prop_id)
			##WyncTrack.prop_set_predict(wctx, vel_prop_id)


static func setup_sync_for_player_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var wctx = gs.wctx
	var actor := PlatPublic.get_actor(gs, actor_id)
	var player_instance := gs.players[actor.instance_id]

	if WyncTrack.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_PLAYER) != OK:
		return

	var pos_prop_id = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncCtx.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Player).position = pos,
	)

	var vel_prop_id = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"velocity",
		WyncCtx.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		vel_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).velocity,
		func(user_ctx: Variant, vel: Vector2): (user_ctx as Plat.Player).velocity = vel,
	)

	var input_prop_id = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"input",
		WyncCtx.PROP_TYPE.INPUT
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		input_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Plat.PlayerInput: return WyncMisc.duplicate_any((user_ctx as Plat.Player).input),
		func(user_ctx: Variant, input: Plat.PlayerInput): input.copyTo((user_ctx as Plat.Player).input),
	)

	WyncPropUtils.prop_enable_interpolation(
		wctx, pos_prop_id, Plat.LERP_TYPE_VECTOR2
	)

	if wctx.common.is_client:
	
		# setup extrapolation
			
		WyncPropUtils.prop_enable_prediction(wctx, pos_prop_id)
		WyncPropUtils.prop_enable_prediction(wctx, vel_prop_id)
		WyncPropUtils.prop_enable_prediction(wctx, input_prop_id)
		#WyncTrack.prop_set_predict(wctx, events_prop_id)
	
	# it is server
	else:
		# time warp
		WyncTimeWarp.prop_set_timewarpable(wctx, pos_prop_id) 
		WyncTimeWarp.prop_set_timewarpable(wctx, input_prop_id) 


static func setup_sync_for_rocket_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var actor := PlatPublic.get_actor(gs, actor_id)
	var wctx = gs.wctx
	var rocket_instance := gs.rockets[actor.instance_id]

	if WyncTrack.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_ROCKET) != OK:
		return

	var pos_prop_id = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncCtx.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		rocket_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Rocket).position,
		#func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Rocket).position = pos,
		func(_user_ctx, _pos): pass,
	)
	WyncPropUtils.prop_enable_interpolation(
		wctx, pos_prop_id, Plat.LERP_TYPE_VECTOR2
	)


static func setup_sync_for_all_chunks(gs: Plat.GameState):
	for i: int in range(Plat.CHUNK_AMOUNT):
		var chunk := gs.chunks[i]
		if chunk == null:
			assert(false)
			continue

		PlatWync.setup_sync_for_chunk_actor(gs, chunk.actor_id)


static func setup_sync_for_chunk_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var actor := PlatPublic.get_actor(gs, actor_id)
	var wctx = gs.wctx
	var chunk_instance := gs.chunks[actor.instance_id]
	assert(chunk_instance != null)

	if WyncTrack.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_CHUNK) != OK:
		assert(false)
		return

	var blocks_prop = WyncTrack.prop_register_minimal(
		wctx,
		actor_id,
		"blocks",
		WyncCtx.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		blocks_prop,
		chunk_instance,
		func(user_ctx: Variant) -> Array[Array]: return PlatPrivate.duplicate_chunk_blocks(user_ctx as Plat.Chunk),
		func(user_ctx: Variant, blocks: Array[Array]): (user_ctx as Plat.Chunk).blocks = blocks,
	)

	# hook blueprint to prop
	var err = WyncPropUtils.prop_enable_relative_sync(
		wctx,
		actor_id,
		blocks_prop,
		Plat.BLUEPRINT_ID_BLOCK_GRID_DELTA,
		true
	)
	assert(err == OK)

	#if not wctx.is_client:
		#assert(false)


#static func system_spawn_entities(gs: Plat.GameState):

	#if gs.wctx.out_pending_entities_to_despawn.size() > 0:
		#despawn_actors(gs.wctx)
	#if gs.wctx.out_pending_entities_to_spawn.size() > 0:
		#client_spawn_actors(gs.wctx)


static func client_event_connected_to_server(gs: Plat.GameState):
	if not WyncJoin.out_client_just_connected_to_server(gs.wctx):
		return

	# setup

	#PlatWync.setup_sync_for_all_chunks(gs)


static func client_handle_spawn_events(gs: Plat.GameState):
	var ctx := gs.wctx

	var event: WyncCtx.EntitySpawnEvent = null

	event = WyncSpawn.wync_get_next_entity_event_spawn(ctx)
	while(event != null):

		if event.spawn:
			client_spawn_actor(gs, event.entity_type_id, event.entity_id, event.spawn_data)
			WyncSpawn.finish_spawning_entity(ctx, event.entity_id)
		else:
			client_despawn_actor(gs, event.entity_id)

		event = WyncSpawn.wync_get_next_entity_event_spawn(ctx)

	# cleanup
	WyncSpawn.wync_system_spawned_props_cleanup(ctx)


static func client_spawn_actor(gs: Plat.GameState, actor_type: int, actor_id: int, _spawn_data: Variant):

	match actor_type:

		Plat.ACTOR_TYPE_BALL:
			# spawn some entity
			var new_actor_id = PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10), actor_id, Plat.BALL_BEHAVIOUR_STATIC)
			assert(new_actor_id != -1)
			assert(new_actor_id == actor_id)

			# setup actor with wync
			setup_sync_for_ball_actor(gs, actor_id)

		Plat.ACTOR_TYPE_PLAYER:
			# spawn some entity
			var new_actor_id = PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(5, 10), actor_id)
			assert(new_actor_id != -1)
			assert(new_actor_id == actor_id)

			# setup actor with wync
			setup_sync_for_player_actor(gs, actor_id)

		Plat.ACTOR_TYPE_ROCKET:
			# spawn some entity
			var new_actor_id = PlatPublic.spawn_rocket(gs, Vector2.ZERO, Vector2.ZERO, actor_id)
			assert(new_actor_id != -1)
			assert(new_actor_id == actor_id)

			# setup actor with wync
			setup_sync_for_rocket_actor(gs, actor_id)

			# unpack spawn data
			var ball_spawn_data = _spawn_data as Plat.RocketSpawnData

			# insert tick to help interpolation
			var res: bool = (
			(WyncStateStore.wync_insert_state_to_entity_prop(
				gs.wctx, actor_id, "position", ball_spawn_data.tick, ball_spawn_data.value1) == OK) &&
			(WyncStateStore.wync_insert_state_to_entity_prop(
				gs.wctx, actor_id, "position", ball_spawn_data.tick + 1, ball_spawn_data.value2) == OK))
			Log.outc(gs.wctx, "success inserting state? %s" % [res])

		Plat.ACTOR_TYPE_CHUNK:
			# chunks already exist on clients, however, spawn event needed to initialize synchronization
			# according to the static user_entity_id, sync with the correct local chunk

			#var actor_id = entity_to_spawn.entity_id

			# get local actor
			var actor: Plat.Actor = PlatPublic.get_actor(gs, actor_id)
			assert(actor != null)

			# is of type chunk
			assert(actor.actor_type == Plat.ACTOR_TYPE_CHUNK)

			setup_sync_for_chunk_actor(gs, actor_id)

		_:
			assert(false)


static func client_despawn_actor(gs: Plat.GameState, actor_id: int):
	PlatPublic.despawn_actor(gs, actor_id)

	# wync cleanup
	#WyncFlow.wync_clear_entities_pending_to_despawn(ctx)


static func update_what_the_clients_can_see(gs: Plat.GameState):
	if (
		WyncMisc.fast_modulus(Engine.get_physics_frames(), 16) == 0
		|| gs.actors_added_or_deleted
	):

		gs.actors_added_or_deleted = false
		var ctx = gs.wctx

		for peer_id in range(1, ctx.common.peers.size()):
			# TODO: get me a list of only active peers!

			#for actor_index: int in range(Plat.ACTOR_AMOUNT):
				#if not gs.actor_ids.has(actor_index):
					#return
				#var actor_id = gs.actor_ids[actor_index]
			for actor_id: int in gs.actor_ids.keys():
				if not WyncTrack.is_entity_tracked(ctx, actor_id):
					continue
				WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, actor_id)
			
			# prob prop
			# Note: Move this to peer setup
			WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS)
			WyncTrack.wync_add_local_existing_entity(ctx, peer_id, WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS)


static func find_out_what_player_i_control(gs: Plat.GameState):
	if gs.i_control_player_id != -1:
		return
	if not gs.wctx.common.connected:
		return

	var ctx = gs.wctx
	for prop_id: int in ctx.co_clientauth.client_owns_prop[ctx.common.my_peer_id]:

		var prop = WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		var prop_name = prop.name_id
		var entity_id = WyncTrack.prop_get_entity(ctx, prop_id)
		var entity_type = ctx.co_track.entity_is_of_type[entity_id]

		# find a prop that I own
		# that is called "inputs"
		# that is of type player

		if (prop_name == "input" && entity_type == Plat.ACTOR_TYPE_PLAYER):

			# Note: asssuming wync's entity_id directly maps to gs.actors[]

			var actor_id = entity_id
			var actor := PlatPublic.get_actor(gs, actor_id)
			gs.i_control_player_id = actor.instance_id
			break


static func extrapolate(gs: Plat.GameState):

	var ctx = gs.wctx
	var target_tick = ctx.co_pred.target_tick

	if WyncXtrap.wync_xtrap_preparation(ctx) != OK:
		return

	#Log.outc(ctx, "starting prediction ==============================")
	var base_tick = ctx.co_pred.pred_intented_first_tick - ctx.co_pred.max_prediction_tick_threeshold
	if (base_tick - 30 < 0):
		return
	for tick in range(ctx.co_pred.pred_intented_first_tick - ctx.co_pred.max_prediction_tick_threeshold, target_tick +1):
	#for tick in range(ctx.pred_intented_first_tick - 8, target_tick +1):

		WyncXtrap.wync_xtrap_tick_init(ctx, tick)
		WyncXtrap.wync_xtrap_regular_entities_to_predict(ctx, tick)

		#Log.outc(ctx, "debugrela to predict %s" % [ctx.global_entity_ids_to_predict])

		PlatPublic.system_player_movement(
			gs, Plat.LOGIC_DELTA_MS, true, ctx.co_pred.global_entity_ids_to_predict)

		PlatPublic.system_client_simulate_own_events(gs, tick)

		# debug trail
		if WyncMisc.fast_modulus(tick, 2) == 0:
			for player_id: int in range(Plat.PLAYER_AMOUNT):
				var player := gs.players[player_id]
				if player == null:
					continue
				if not WyncXtrap.entity_is_predicted(ctx, player.actor_id):
					continue
				#var progress = (float(tick) - ctx.last_tick_received) / (target_tick - ctx.last_tick_received)
				#var progress = float(tick - (target_tick - 28)) / 10
				var progress = float(tick - base_tick) / 10
				var prop_position = WyncTrack.entity_get_prop_id(ctx, player.actor_id, "position")
				if prop_position:
					var getter = ctx.wrapper.prop_getter[prop_position]
					var user_ctx = ctx.wrapper.prop_user_ctx[prop_position]
					PlatPublic.spawn_box_trail(gs, getter.call(user_ctx), progress, 1)



		WyncXtrap.wync_xtrap_tick_end(ctx, tick)
		#PlatPublic.debug_print_last_chunk(gs)
	#Log.outc(ctx, "debugging prediction range (%s : %s) d %s | server_ticks %s" % [ctx.pred_intented_first_tick, target_tick +1, (target_tick+1-ctx.pred_intented_first_tick), ctx.co_ticks.server_ticks])
	
	WyncXtrap.wync_xtrap_termination(ctx)


static func set_interpolated_state(gs: Plat.GameState):

	#for actor_id: int in 
	#for ball_id: int in gs.balls:
		#var ball := gs.balls[ball_id]
		#if ball = null:
			#break
	var ctx := gs.wctx
	
	#for actor_id: int in range(gs.actors.size()):
	for actor_id: int in gs.actor_ids.keys():
		var actor := PlatPublic.get_actor(gs, actor_id)

		# TODO: keep a list of active actors
		# for now just break
		if actor == null:
			break

		if not WyncTrack.is_entity_tracked(ctx, actor_id):
			continue
		var prop = WyncTrack.entity_get_prop(ctx, actor_id, "position")
		if prop == null || prop.co_lerp.interpolated_state == null:
			continue
		#Log.outc(gs.wctx, "deblerp | prop.interpolated_state %s" % [prop.interpolated_state])

		match actor.actor_type:
			Plat.ACTOR_TYPE_BALL:
				var instance := gs.balls[actor.instance_id]
				instance.position = prop.co_lerp.interpolated_state
			Plat.ACTOR_TYPE_PLAYER:
				var instance := gs.players[actor.instance_id]
				instance.visual_position = prop.co_lerp.interpolated_state
			Plat.ACTOR_TYPE_ROCKET:
				var instance := gs.rockets[actor.instance_id]
				instance.position = prop.co_lerp.interpolated_state
			_:
				assert(false)


	#for entity: Entity in entities:

		#var co_actor = entity.get_component(CoActor.label) as CoActor
		#var co_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer

		## is prop interpolable (aka numeric, Vector2)

		#if not WyncTrack.is_entity_tracked(wync_ctx, co_actor.id):
			#continue
			
		#var prop = WyncTrack.entity_get_prop(wync_ctx, co_actor.id, "position")
		#if (prop != null
			#&& prop.interpolated_state != null
			#&& co_renderer is Node2D):
			#co_renderer.global_position = prop.interpolated_state
			
			## it's up to the user to do extra interpolation if they want
			##wco_renderer.global_position = co_renderer.global_position.lerp(prop.interpolated_state, 0.9)
			
			## simple
			#DebugPlayerTrail.spawn(self, co_renderer.global_position, 0.5, 0, true)

			## long trail
			##DebugPlayerTrail.spawn(self, co_renderer.global_position, wync_ctx.co_ticks.lerp_delta_accumulator_ms / 1000.0, 1, false, -10)
				
		
		## 1. aim is currently interpolated by Wync
		## 2. apply this value to the visual Ball
		#prop = WyncTrack.entity_get_prop(wync_ctx, co_actor.id, "aim")
		#if (prop != null
			#&& prop.interpolated_state != null
			#&& co_renderer is Node2D):
			#co_renderer.rotation = prop.interpolated_state
		

## Draws left and right states for interpolation
## Also draws latest received state
static func debug_draw_confirmed_interpolated_states(gs: Plat.GameState):

	var ctx = gs.wctx

	var left_value: Variant
	var right_value: Variant

	for prop_id in ctx.co_filter_c.type_state__interpolated_regular_prop_ids:
		var prop := WyncTrack.get_prop_unsafe(ctx, prop_id)

		if prop.co_lerp.lerp_use_confirmed_state:
			left_value = prop.co_lerp.lerp_left_state
			right_value = prop.co_lerp.lerp_right_state
			#last_value = prop.confirmed_states.get_at(prop.last_ticks_received.get_relative(0))
			

			# create debug hulls

			PlatPublic.spawn_box_trail(gs, left_value + Vector2(0,-15), 0.5, 0)
			PlatPublic.spawn_box_trail(gs, right_value + Vector2(0,-15), 0.0, 0)
			#if last_value is Vector2: PlatPublic.spawn_trail(gs, last_value, 0.4, 0)


## Draws all confirmed states for a given prop
static func debug_draw_confirmed_states(gs: Plat.GameState, prop_id: int):

	var ctx = gs.wctx

	var prop := WyncTrack.get_prop(ctx, prop_id)
	#Log.outc(gs.wctx, "debtrail, prop %s" % prop)
	if prop == null:
		return

	for i in range(prop.statebff.saved_states.size):
		var state = prop.statebff.saved_states.get_relative(-i)
		if state is Vector2:
			state += Vector2(0, -11)
			PlatPublic.spawn_box_trail(gs, state, (float(i) / prop.statebff.saved_states.size) / 4.0, 0)
			#Log.outc(gs.wctx, "debtrail, got state %s" % state)


static func debug_draw_timewarped_state(
	gs: Plat.GameState, prop_ids: Array[int], hue: float):
	#gs: Plat.GameState, prop_ids: Array[int], event: Plat.EventPlayerShootTimewarp):

	var ctx = gs.wctx
	
	for prop_id: int in prop_ids:
		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.name_id != "position":
			continue

		# get size by getting the ball

		var entity: int = WyncTrack.prop_get_entity(gs.wctx, prop_id)
		assert(entity != -1)

		var actor: Plat.Actor = PlatPublic.get_actor(gs, entity)
		assert(actor.actor_type == Plat.ACTOR_TYPE_BALL)

		var ball := gs.balls[actor.instance_id]

		PlatPublic.spawn_box_trail_size(gs, prop.co_lerp.interpolated_state, ball.size, hue, 1.5*60)
