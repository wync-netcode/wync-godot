class_name PlatWync


static func setup_server(ctx: WyncCtx):
	ctx.co_ticks.ticks = 0
	WyncUtils.server_setup(ctx)
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	setup_blueprints(ctx)


static func setup_client(ctx: WyncCtx):
	ctx.co_ticks.ticks = 200
	WyncUtils.client_init(ctx)
	
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	WyncUtils.clock_set_debug_time_offset(ctx, 1000)

	# set server tick rate and lerp_ms
	var server_tick_rate: int = ctx.physic_ticks_per_second
	var desired_lerp: int = ceil((1000.0 / server_tick_rate) * 5) # 6 ticks in the past
	WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, desired_lerp)
	WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, 600)

	WyncWrapper.wync_register_lerp_type(
		ctx, Plat.LERP_TYPE_FLOAT,
		func (a: float, b: float, weight: float): return lerp(a, b, weight)
	)
	WyncWrapper.wync_register_lerp_type(
		ctx, Plat.LERP_TYPE_VECTOR2,
		func (a: Vector2, b: Vector2, weight: float): return lerp(a, b, weight)
	)
	setup_blueprints(ctx)


static func setup_connect_client(gs: Plat.GameState):
	var ctx := gs.wctx
	for nete_peer_id: int in ctx.out_peer_pending_to_setup:

		#pass
		# get wync_peer_id
		var wync_peer_id = WyncUtils.is_peer_registered(ctx, nete_peer_id)
		assert(wync_peer_id != -1)

		# spawn some entity
		var actor_id = PlatPublic.spawn_player_server(gs, PlatUtils.GRID_CORD(5, 5))

		# setup actor with wync
		setup_sync_for_player_actor(gs, actor_id)

		# give client authority over prop
		for prop_name_id: String in ["input"]:
			var prop_id = WyncUtils.entity_get_prop_id(ctx, actor_id, prop_name_id)
			WyncUtils.prop_set_client_owner(ctx, prop_id, wync_peer_id)

		# Note: In bigger games with different levels you might set this up also on level change
		setup_new_client_level_props(gs, wync_peer_id)

	WyncUtils.clear_peers_pending_to_setup(ctx)


# setup entities that the client should already have present
static func setup_new_client_level_props(gs: Plat.GameState, wync_peer_id: int):
	return

	# chunk entities should be present
	#for i: int in range(Plat.CHUNK_AMOUNT):
		#var chunk := gs.chunks[i]
		#if chunk == null:
			#continue
		#WyncThrottle.wync_add_local_existing_entity(gs.wctx, wync_peer_id, chunk.actor_id)


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
	(user_ctx: Variant, event: WyncEvent.EventData, requires_undo: bool, ctx: WyncCtx) -> Array[int]:
	
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

	if WyncUtils.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_BALL) != OK:
		return

	var pos_prop_id = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncEntityProp.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		ball_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Ball).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Ball).position = pos,
	)
	WyncUtils.prop_set_interpolate(
		wctx, pos_prop_id, Plat.LERP_TYPE_VECTOR2
	)

	#var pos_prop_id = WyncUtils.prop_register(
		#wctx,
		#actor_id,
		#"position",
		#WyncEntityProp.DATA_TYPE.VECTOR2,
		#ball_instance,
		#func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Ball).position,
		#func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Ball).position = pos,
	#)
	#var vel_prop_id = WyncUtils.prop_register(
		#wctx,
		#actor_id,
		#"velocity",
		#WyncEntityProp.DATA_TYPE.VECTOR2,
		#ball_instance,
		#func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Ball).velocity,
		#func(user_ctx: Variant, vel: Vector2): (user_ctx as Plat.Ball).velocity = vel,
	#)

	#if WyncUtils.is_client(wctx):
		## interpolation
		
		#WyncUtils.prop_set_interpolate(wctx, pos_prop_id)
		#WyncUtils.prop_set_interpolate(wctx, vel_prop_id)
		##WyncUtils.prop_set_interpolate(wctx, aim_prop_id) # TODO
		
		## setup extrapolation

		##if co_actor.id % 2 == 0:
			##WyncUtils.prop_set_predict(wctx, pos_prop_id)
			##WyncUtils.prop_set_predict(wctx, vel_prop_id)
	
	## it is server
	#else:
		## time warp
		#WyncUtils.prop_set_timewarpable(wctx, pos_prop_id) 


static func setup_sync_for_player_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var wctx = gs.wctx
	var actor := PlatPublic.get_actor(gs, actor_id)
	var player_instance := gs.players[actor.instance_id]

	if WyncUtils.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_PLAYER) != OK:
		return

	var pos_prop_id = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncEntityProp.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Player).position = pos,
	)

	var vel_prop_id = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"velocity",
		WyncEntityProp.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		vel_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).velocity,
		func(user_ctx: Variant, vel: Vector2): (user_ctx as Plat.Player).velocity = vel,
	)

	var input_prop_id = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"input",
		WyncEntityProp.PROP_TYPE.INPUT
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		input_prop_id,
		player_instance,
		func(user_ctx: Variant) -> Plat.PlayerInput: return WyncUtils.duplicate_any((user_ctx as Plat.Player).input),
		func(user_ctx: Variant, input: Plat.PlayerInput): (user_ctx as Plat.Player).input = input,
	)

	if wctx.is_client:
		# interpolation
		
		WyncUtils.prop_set_interpolate(
			wctx, pos_prop_id, Plat.LERP_TYPE_VECTOR2
		)
	
		# setup extrapolation
			
		WyncUtils.prop_set_predict(wctx, pos_prop_id)
		WyncUtils.prop_set_predict(wctx, vel_prop_id)
		WyncUtils.prop_set_predict(wctx, input_prop_id)
		#WyncUtils.prop_set_predict(wctx, events_prop_id)
	
	# it is server
	else:
		# time warp
		WyncUtils.prop_set_timewarpable(wctx, pos_prop_id) 


static func setup_sync_for_rocket_actor(gs: Plat.GameState, actor_id: int):
	#if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT: assert(false)
	var actor := PlatPublic.get_actor(gs, actor_id)
	var wctx = gs.wctx
	var rocket_instance := gs.rockets[actor.instance_id]

	if WyncUtils.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_ROCKET) != OK:
		return

	var pos_prop_id = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"position",
		WyncEntityProp.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		pos_prop_id,
		rocket_instance,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Rocket).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Rocket).position = pos,
	)
	WyncUtils.prop_set_interpolate(
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

	if WyncUtils.track_entity(wctx, actor_id, Plat.ACTOR_TYPE_CHUNK) != OK:
		assert(false)
		return

	var blocks_prop = WyncUtils.prop_register_minimal(
		wctx,
		actor_id,
		"blocks",
		WyncEntityProp.PROP_TYPE.STATE
	)
	WyncWrapper.wync_set_prop_callbacks(
		wctx,
		blocks_prop,
		chunk_instance,
		func(user_ctx: Variant) -> Array[Array]: return PlatPrivate.duplicate_chunk_blocks(user_ctx as Plat.Chunk),
		func(user_ctx: Variant, blocks: Array[Array]): (user_ctx as Plat.Chunk).blocks = blocks,
	)

	# hook blueprint to prop
	var err = WyncDeltaSyncUtils.prop_set_relative_syncable(
		wctx,
		actor_id,
		blocks_prop,
		Plat.BLUEPRINT_ID_BLOCK_GRID_DELTA,
		false
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
	if not WyncUtils.out_client_just_connected_to_server(gs.wctx):
		return

	# setup

	#PlatWync.setup_sync_for_all_chunks(gs)



static func client_handle_spawn_events(gs: Plat.GameState):
	var ctx := gs.wctx

	var event: WyncCtx.EntitySpawnEvent = null

	event = WyncFlow.wync_get_next_entity_event_spawn(ctx)
	while(event != null):

		if event.spawn:
			client_spawn_actor(gs, event.entity_type_id, event.entity_id, event.spawn_data)
			WyncUtils.finish_spawning_entity(ctx, event.entity_id)
		else:
			client_despawn_actor(gs, event.entity_id)

		event = WyncFlow.wync_get_next_entity_event_spawn(ctx)

	# cleanup
	WyncFlow.wync_system_spawned_props_cleanup(ctx)


static func client_spawn_actor(gs: Plat.GameState, actor_type: int, actor_id: int, _spawn_data: Variant):

	match actor_type:

		Plat.ACTOR_TYPE_BALL:
			# spawn some entity
			var new_actor_id = PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10), actor_id)
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
		WyncUtils.fast_modulus(Engine.get_physics_frames(), 16) == 0
		|| gs.actors_added_or_deleted
	):

		gs.actors_added_or_deleted = false
		var ctx = gs.wctx

		for peer_id in range(1, ctx.peers.size()):
			# TODO: get me a list of only active peers!

			#for actor_index: int in range(Plat.ACTOR_AMOUNT):
				#if not gs.actor_ids.has(actor_index):
					#return
				#var actor_id = gs.actor_ids[actor_index]
			for actor_id: int in gs.actor_ids.keys():
				if not WyncUtils.is_entity_tracked(ctx, actor_id):
					continue
				WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, actor_id)
			
			# prob prop
			# Note: Move this to peer setup
			WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS)
			WyncThrottle.wync_add_local_existing_entity(ctx, peer_id, WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS)


static func find_out_what_player_i_control(gs: Plat.GameState):
	if gs.i_control_player_id != -1:
		return
	if not gs.wctx.connected:
		return

	var ctx = gs.wctx
	for prop_id: int in ctx.client_owns_prop[ctx.my_peer_id]:

		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		var prop_name = prop.name_id
		var entity_id = WyncUtils.prop_get_entity(ctx, prop_id)
		var entity_type = ctx.entity_is_of_type[entity_id]

		# find a prop that I own
		# that is called "inputs"
		# that is of type player

		if (prop_name == "input" && entity_type == Plat.ACTOR_TYPE_PLAYER):

			# Note: asssuming wync's entity_id directly maps to gs.actors[]

			var actor_id = entity_id
			var actor := PlatPublic.get_actor(gs, actor_id)
			gs.i_control_player_id = actor.instance_id
			break


static func extrapolate(gs: Plat.GameState, delta: float):

	var ctx = gs.wctx
	var target_tick = ctx.co_predict_data.target_tick

	if WyncXtrap.wync_xtrap_preparation(ctx) != OK:
		return

	#Log.outc(ctx, "starting prediction ==============================")
	var base_tick = ctx.pred_intented_first_tick - ctx.max_prediction_tick_threeshold
	if (base_tick - 30 < 0):
		return
	for tick in range(ctx.pred_intented_first_tick - ctx.max_prediction_tick_threeshold, target_tick +1):
		#Log.outc(ctx, "pred_tick %s" % [tick])
		WyncXtrap.wync_xtrap_tick_init(ctx, tick)
		var entity_ids_to_predict = WyncXtrap.wync_xtrap_dont_predict_entities(ctx, tick)
		#Log.outc(ctx, "dont_predict_entities %s" % [dont_predict_entity_ids])
		#Log.outc(ctx, "xtrap, entity_ids_to_predict %s" % [entity_ids_to_predict])
		PlatPublic.system_player_movement(gs, Plat.LOGIC_DELTA_MS, true, entity_ids_to_predict)

		# debug trail
		if WyncUtils.fast_modulus(tick, 2) == 0:
			for player_id: int in range(Plat.PLAYER_AMOUNT):
				var player := gs.players[player_id]
				if player == null:
					continue
				if not WyncUtils.entity_is_predicted(ctx, player.actor_id):
					continue
				#var progress = (float(tick) - ctx.last_tick_received) / (target_tick - ctx.last_tick_received)
				#var progress = float(tick - (target_tick - 28)) / 10
				var progress = float(tick - base_tick) / 10
				var prop_position = WyncUtils.entity_get_prop_id(ctx, player.actor_id, "position")
				if prop_position:
					var getter = ctx.wrapper.prop_getter[prop_position]
					var user_ctx = ctx.wrapper.prop_user_ctx[prop_position]
					PlatPublic.spawn_trail(gs, getter.call(user_ctx), progress, 1)



		WyncXtrap.wync_xtrap_tick_end(ctx, tick)
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

		if not WyncUtils.is_entity_tracked(ctx, actor_id):
			continue
		var prop = WyncUtils.entity_get_prop(ctx, actor_id, "position")
		if prop == null || prop.interpolated_state == null:
			continue
		#Log.outc(gs.wctx, "deblerp | prop.interpolated_state %s" % [prop.interpolated_state])

		match actor.actor_type:
			Plat.ACTOR_TYPE_BALL:
				var instance := gs.balls[actor.instance_id]
				instance.position = prop.interpolated_state
			Plat.ACTOR_TYPE_PLAYER:
				var instance := gs.players[actor.instance_id]
				instance.visual_position = prop.interpolated_state
			Plat.ACTOR_TYPE_ROCKET:
				var instance := gs.rockets[actor.instance_id]
				instance.position = prop.interpolated_state
			_:
				assert(false)


	#for entity: Entity in entities:

		#var co_actor = entity.get_component(CoActor.label) as CoActor
		#var co_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer

		## is prop interpolable (aka numeric, Vector2)

		#if not WyncUtils.is_entity_tracked(wync_ctx, co_actor.id):
			#continue
			
		#var prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "position")
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
		#prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "aim")
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
	var last_value: Variant

	for prop_id in ctx.type_state__interpolated_regular_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)

		if prop.lerp_use_confirmed_state:
			left_value = prop.lerp_left_state
			right_value = prop.lerp_right_state
			#last_value = prop.confirmed_states.get_at(prop.last_ticks_received.get_relative(0))
			

			# create debug hulls

			PlatPublic.spawn_trail(gs, left_value + Vector2(0,-15), 0.5, 0)
			PlatPublic.spawn_trail(gs, right_value + Vector2(0,-15), 0.0, 0)
			#if last_value is Vector2: PlatPublic.spawn_trail(gs, last_value, 0.4, 0)


## Draws all confirmed states for a given prop
static func debug_draw_confirmed_states(gs: Plat.GameState, prop_id: int):

	var ctx = gs.wctx

	var prop := WyncUtils.get_prop(ctx, prop_id)
	#Log.outc(gs.wctx, "debtrail, prop %s" % prop)
	if prop == null:
		return

	for i in range(prop.saved_states.size):
		var state = prop.saved_states.get_relative(-i)
		if state is Vector2:
			PlatPublic.spawn_trail(gs, state, (float(i) / prop.saved_states.size) / 4.0, 0)
			#Log.outc(gs.wctx, "debtrail, got state %s" % state)
