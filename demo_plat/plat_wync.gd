class_name PlatWync


static func setup_server(ctx: WyncCtx):
	WyncUtils.server_setup(ctx)
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)


static func setup_client(ctx: WyncCtx):
	ctx.co_ticks.ticks = 200
	WyncUtils.client_init(ctx)
	
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	WyncUtils.clock_set_debug_time_offset(ctx, 1000)

	# set server tick rate and lerp_ms
	var server_tick_rate: int = ctx.physic_ticks_per_second
	#var desired_lerp: int = ceil((1000.0 / server_tick_rate) * 6) # 6 ticks in the past
	WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, 200)


static func setup_connect_client(gs: Plat.GameState):
	var ctx := gs.wctx
	for nete_peer_id: int in ctx.out_peer_pending_to_setup:

		# get wync_peer_id
		var wync_peer_id = WyncUtils.is_peer_registered(ctx, nete_peer_id)
		assert(wync_peer_id != -1)

		# spawn some entity
		var player_actor_id = PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(5, 10))

		# setup actor with wync
		setup_sync_for_player_actor(gs, player_actor_id)

		# give client authority over prop
		for prop_name_id: String in ["input"]:
			var prop_id = WyncUtils.entity_get_prop_id(ctx, player_actor_id, prop_name_id)
			WyncUtils.prop_set_client_owner(ctx, prop_id, wync_peer_id)

	WyncUtils.clear_peers_pending_to_setup(ctx)


static func setup_sync_for_player_actor(gs: Plat.GameState, player_id: int):
	var wctx = gs.wctx
	var player_actor := gs.players[player_id]
	var actor_id := player_id

	WyncUtils.track_entity(wctx, actor_id, GameInfo.ENTITY_TYPE_PLAYER)

	var pos_prop_id = WyncUtils.prop_register(
		wctx,
		actor_id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		player_actor,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).position,
		func(user_ctx: Variant, pos: Vector2): (user_ctx as Plat.Player).position = pos,
	)
	var vel_prop_id = WyncUtils.prop_register(
		wctx,
		actor_id,
		"velocity",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		player_actor,
		func(user_ctx: Variant) -> Vector2: return (user_ctx as Plat.Player).velocity,
		func(user_ctx: Variant, vel: Vector2): (user_ctx as Plat.Player).velocity = vel,
	)
	var input_prop_id = WyncUtils.prop_register(
		wctx,
		actor_id,
		"input",
		WyncEntityProp.DATA_TYPE.INPUT,
		player_actor,
		func(user_ctx: Variant) -> Plat.PlayerInput: return WyncUtils.duplicate_any((user_ctx as Plat.Player).input),
		func(user_ctx: Variant, input: Plat.PlayerInput): (user_ctx as Plat.Player).input = input,
	)

	if wctx.is_client:
		# interpolation
		
		WyncUtils.prop_set_interpolate(wctx, pos_prop_id)
		WyncUtils.prop_set_interpolate(wctx, vel_prop_id)
	
		# setup extrapolation
			
		WyncUtils.prop_set_predict(wctx, pos_prop_id)
		WyncUtils.prop_set_predict(wctx, vel_prop_id)
		WyncUtils.prop_set_predict(wctx, input_prop_id)
		#WyncUtils.prop_set_predict(wctx, events_prop_id)
	
	# it is server
	else:
		
		# time warp
		WyncUtils.prop_set_timewarpable(wctx, pos_prop_id) 


#static func system_spawn_entities(gs: Plat.GameState):

	#if gs.wctx.out_pending_entities_to_despawn.size() > 0:
		#despawn_actors(gs.wctx)
	#if gs.wctx.out_pending_entities_to_spawn.size() > 0:
		#client_spawn_actors(gs.wctx)


static func client_spawn_actors(gs: Plat.GameState, ctx: WyncCtx):

	if gs.wctx.out_pending_entities_to_spawn.size() <= 0:
		return

	#assert(false)
	for i in range(ctx.out_pending_entities_to_spawn.size()):

		var entity_to_spawn: WyncCtx.PendingEntityToSpawn = ctx.out_pending_entities_to_spawn[i]

		match entity_to_spawn.entity_type_id:

			GameInfo.ENTITY_TYPE_PLAYER:
				#var spawn_data = entity_to_spawn.spawn_data as GameInfo.EntityProjectileSpawnData

				# spawn some entity
				var player_actor_id = PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(5, 10), entity_to_spawn.entity_id)
				assert(player_actor_id != -1)

				# setup actor with wync
				setup_sync_for_player_actor(gs, player_actor_id)

				WyncUtils.finish_spawning_entity(ctx, entity_to_spawn.entity_id, i)

	# wync cleanup
	WyncFlow.wync_system_spawned_props_cleanup(ctx)


static func update_what_the_clients_can_see(gs: Plat.GameState):
	if (
		WyncUtils.fast_modulus(Engine.get_physics_frames(), 16) == 0
		|| gs.actors_added_or_deleted
	):

		gs.actors_added_or_deleted = false
		var ctx = gs.wctx

		## For the moment just sync gs.Players

		for peer_id in range(1, ctx.peers.size()):
			# TODO: get me a list of only active peers!

			for player_actor_id: int in range(Plat.PLAYER_AMOUNT):
				if not WyncUtils.is_entity_tracked(ctx, player_actor_id):
					continue
				WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, player_actor_id)

				#k

			## map local entities
			#for actor_id in range(0, 5 + 1):
				#if co_actors.actors.size() <= actor_id:
					#continue
				#if co_actors.actors[actor_id] == null:
					#continue

				## deleteme debug
				#if actor_id == 3:
					#continue

				#WyncThrottle.wync_client_now_can_see_entity(ctx, peer_id, actor_id)
				#WyncThrottle.wync_add_local_existing_entity(ctx, peer_id, actor_id)

			## 
			
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

		if (prop_name == "input" && entity_type == GameInfo.ENTITY_TYPE_PLAYER):
			# NOTE: asssuming entity_id directly maps to gs.players[]
			gs.i_control_player_id = entity_id
			break
