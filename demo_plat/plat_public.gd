class_name PlatPublic


## @returns int. id or -1 if not found
static func actor_find_available_id(gs: Plat.GameState) -> int:
	var instance_id = -1
	for i: int in range(Plat.ACTOR_AMOUNT):
		if gs.actors[i] == null:
			instance_id = i
			break
	return instance_id


## @returns int. id or -1 if not found
static func ball_find_available_id(gs: Plat.GameState) -> int:
	var instance_id = -1
	for i: int in range(Plat.BALL_AMOUNT):
		if gs.balls[i] == null:
			instance_id = i
			break
	return instance_id


## @returns int. id or -1 if not found
static func player_find_available_id(gs: Plat.GameState) -> int:
	var instance_id = -1
	for i: int in range(Plat.PLAYER_AMOUNT):
		if gs.players[i] == null:
			instance_id = i
			break
	return instance_id


## @returns int. id or -1 if not found
static func rocket_find_available_id(gs: Plat.GameState) -> int:
	var instance_id = -1
	for i: int in range(Plat.ROCKET_AMOUNT):
		if gs.rockets[i] == null:
			instance_id = i
			break
	return instance_id


static func get_actor(gs: Plat.GameState, actor_id: int) -> Plat.Actor:
	return gs.actors[gs.actor_ids[actor_id]]


static func spawn_actor(gs: Plat.GameState, actor_id: int, actor_type: int, instance_id: int):
	var actor = Plat.Actor.new()
	actor.actor_type = actor_type
	actor.instance_id = instance_id
	var actor_index = actor_find_available_id(gs)
	gs.actors[actor_index] = actor
	gs.actor_ids[actor_id] = actor_index


static func despawn_actor(gs: Plat.GameState, actor_id: int):
	if actor_id < 0 || actor_id >= Plat.ACTOR_AMOUNT || not gs.actor_ids.has(actor_id):
		assert(false)
		return

	var actor_index = gs.actor_ids[actor_id]
	gs.actor_ids.erase(actor_id)

	var actor := gs.actors[actor_index]
	if actor == null:
		assert(false)
		return

	# clean specific instance
	match actor.actor_type:
		Plat.ACTOR_TYPE_ROCKET:
			if not (actor.instance_id < 0 || actor.instance_id >= Plat.ROCKET_AMOUNT):
				gs.rockets[actor.instance_id] = null
		_:
			assert(false)

	gs.actors[actor_index] = null

	# clean from wync
	if WyncUtils.is_entity_tracked(gs.wctx, actor_id):
		WyncUtils.untrack_entity(gs.wctx, actor_id)
	
	Log.outc(gs.wctx, "spawn, despawned entity %s" % [actor_id])


## @returns int. actor_id or -1
static func spawn_ball_server(gs: Plat.GameState, origin: Vector2) -> int:
	var actor_id = actor_find_available_id(gs)
	gs.actors_added_or_deleted = true
	return spawn_ball(gs, origin, actor_id)


## @returns int. actor_id or -1
static func spawn_ball(gs: Plat.GameState, origin: Vector2, actor_id: int) -> int:
	var ball_id = ball_find_available_id(gs)
	if actor_id == -1 || ball_id == -1:
		return -1

	var ball = Plat.Ball.new()
	ball.actor_id = actor_id
	ball.position = origin
	ball.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 1.5)
	ball.velocity.x = Plat.BALL_MAX_SPEED
	gs.balls[ball_id] = ball
	spawn_actor(gs, actor_id, Plat.ACTOR_TYPE_BALL, ball_id)
	return actor_id


## @returns int. actor_id or -1
static func spawn_player_server(gs: Plat.GameState, origin: Vector2) -> int:
	var actor_id = actor_find_available_id(gs)
	gs.actors_added_or_deleted = true
	return spawn_player(gs, origin, actor_id)


## @returns int. actor_id or -1
static func spawn_player(gs: Plat.GameState, origin: Vector2, actor_id: int) -> int:
	var player_id = player_find_available_id(gs)
	if actor_id == -1 || player_id == -1:
		return -1

	var player = Plat.Player.new()
	player.actor_id = actor_id
	player.position = origin
	player.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 1.5)
	player.input = Plat.PlayerInput.new()
	gs.players[player_id] = player
	spawn_actor(gs, actor_id, Plat.ACTOR_TYPE_PLAYER, player_id)
	return actor_id


## @returns int. actor_id or -1
static func spawn_rocket_server(gs: Plat.GameState, origin: Vector2, direction: Vector2) -> int:
	var actor_id = actor_find_available_id(gs)
	gs.actors_added_or_deleted = true
	return spawn_rocket(gs, origin, direction, actor_id)


## @returns int. actor_id or -1
static func spawn_rocket(gs: Plat.GameState, origin: Vector2, direction: Vector2, actor_id: int) -> int:
	var rocket_id = rocket_find_available_id(gs)
	if actor_id == -1 || rocket_id == -1:
		return -1

	var rocket = Plat.Rocket.new()
	rocket.actor_id = actor_id
	rocket.position = origin
	rocket.direction = direction
	rocket.time_to_live_ms = Plat.ROCKET_TIME_TO_LIVE_MS
	rocket.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.5), round(Plat.BLOCK_LENGTH_PIXELS * 0.5))
	gs.rockets[rocket_id] = rocket
	spawn_actor(gs, actor_id, Plat.ACTOR_TYPE_ROCKET, rocket_id)
	return actor_id


static func spawn_trail(gs: Plat.GameState, origin: Vector2, hue: float, tick_duration: int):
	var trail = Plat.Trail.new()
	trail.position = origin
	trail.hue = hue
	trail.tick_duration = tick_duration
	gs.trails.append(trail)


static func system_trail_lives(gs: Plat.GameState):
	for trail_id: int in range(gs.trails.size()-1, -1, -1):
		var trail := gs.trails[trail_id]
		if trail == null:
			gs.trails.remove_at(trail_id)
		if trail.tick_duration <= 0:
			gs.trails.remove_at(trail_id)
		trail.tick_duration -= 1


static func block_is_solid(block: Plat.Block) -> bool:
	return block.type != Plat.BLOCK_TYPE_AIR


static func system_ball_movement(gs: Plat.GameState):
	for ball: Plat.Ball in gs.balls:
		if ball == null:
			continue
		# velocity
		ball.velocity.y -= Plat.BALL_GRAVITY
		#ball.velocity.x = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.x)) * sign(ball.velocity.x)
		#ball.velocity.y = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.y)) * sign(ball.velocity.y)
		#var new_pos = ball.position + ball.velocity
		#var new_pos = ball.position + Vector2(ball.velocity.x, 0)
		var new_pos = ball.position + Vector2(ball.velocity.x, 3*sin(Time.get_ticks_msec()/120.0))

		# collision
		var collision_horizontal = Rect2Col.rect_collides_with_tile_map(
			Rect2(Vector2(new_pos.x, ball.position.y), ball.size),
			gs.chunks,
			Plat.CHUNK_WIDTH_BLOCKS,
			Plat.CHUNK_HEIGHT_BLOCKS,
			Plat.BLOCK_LENGTH_PIXELS,
			Vector2.ZERO
		)
		var collision_vertical = Rect2Col.rect_collides_with_tile_map(
			Rect2(Vector2(ball.position.x, new_pos.y), ball.size),
			gs.chunks,
			Plat.CHUNK_WIDTH_BLOCKS,
			Plat.CHUNK_HEIGHT_BLOCKS,
			Plat.BLOCK_LENGTH_PIXELS,
			Vector2.ZERO
		)
		if collision_horizontal:
			ball.velocity.x *= -1
		else:
			ball.position.x = new_pos.x
		if collision_vertical && ball.velocity.y < 0:
			ball.velocity.y = 8
		else:
			ball.position.y = new_pos.y

		if ball.position.x > 1500: ball.position.x = 300


static func system_player_movement(gs: Plat.GameState, delta: float, filter: bool, to_predict_entity_ids: Array[int]):

	for player_id: int in range(Plat.PLAYER_AMOUNT):
	#for player: Plat.Player in gs.players:
		var player := gs.players[player_id]
		if player == null:
			continue
		if filter && not to_predict_entity_ids.has(player.actor_id):
			continue
		#if gs.net.is_client: Log.outc(gs.wctx, "plapre, Predicting player %s tick %s" % [player_id, gs.wctx.current_predicted_tick])
		
		# horizontal movement ----------
		# apply friction

		var direction_h = sign(player.velocity.x)
		var speed_h = abs(player.velocity.x)
		var friction: float = Plat.PLAYER_FRICTION * delta
		if speed_h < friction:
			player.velocity.x = 0
		else:
			player.velocity.x -= direction_h * friction
		speed_h = abs(player.velocity.x)

		# apply input

		var increment = sign(player.input.movement_dir.x) * Plat.PLAYER_ACC * delta
		var max_speed = Plat.PLAYER_MAX_SPEED
		var curr_speed = speed_h
		var would_be_speed = abs(player.velocity.x + increment)

		# Two cases:
		# (1) reduce speed

		if would_be_speed < curr_speed:
			player.velocity.x += increment

		# (2) increase speed
		else:

			# allow to achieve maximum speed
			if curr_speed < max_speed && would_be_speed > max_speed:
				curr_speed = max_speed

			# allow to move from stall
			elif would_be_speed <= max_speed:
				curr_speed += abs(increment)

			# merge directions
			var dir = sign(player.velocity.x + increment)
			player.velocity.x = dir * curr_speed

		# vertical movement ----------
		player.velocity.y -= Plat.PLAYER_GRAVITY * delta
		if player.velocity.y < 0:
			player.velocity.y = min(Plat.PLAYER_MAX_SPEED, abs(player.velocity.y)) * sign(player.velocity.y)
		var on_floor = Rect2Col.rect_collides_with_tile_map(
			Rect2(Vector2(player.position.x, player.position.y - 1), player.size),
			gs.chunks,
			Plat.CHUNK_WIDTH_BLOCKS,
			Plat.CHUNK_HEIGHT_BLOCKS,
			Plat.BLOCK_LENGTH_PIXELS,
			Vector2.ZERO
		)
		if on_floor and player.input.movement_dir.y < 0:
			player.velocity.y = Plat.PLAYER_JUMP_SPEED


		# integrate
		var new_pos = player.position + player.velocity
		var collision_horizontal = Rect2Col.rect_collides_with_tile_map(
			Rect2(Vector2(new_pos.x, player.position.y), player.size),
			gs.chunks,
			Plat.CHUNK_WIDTH_BLOCKS,
			Plat.CHUNK_HEIGHT_BLOCKS,
			Plat.BLOCK_LENGTH_PIXELS,
			Vector2.ZERO
		)
		var collision_vertical = Rect2Col.rect_collides_with_tile_map(
			Rect2(Vector2(
				player.position.x if collision_horizontal else new_pos.x,
				new_pos.y
			), player.size),
			gs.chunks,
			Plat.CHUNK_WIDTH_BLOCKS,
			Plat.CHUNK_HEIGHT_BLOCKS,
			Plat.BLOCK_LENGTH_PIXELS,
			Vector2.ZERO
		)
		if not collision_horizontal:
			player.position.x = new_pos.x
		else:
			player.velocity.x = 0
		if not collision_vertical:
			player.position.y = new_pos.y
		else: # allow it to fall / hit his head slowly
			player.velocity.y /= 2

		if player.position.x > 800: player.position.x = 50


static func system_rocket_movement(gs: Plat.GameState, test_only: bool):
	for rocket: Plat.Rocket in gs.rockets:
		if rocket == null:
			continue
		individual_rocket_movement(gs, rocket, test_only)


static func individual_rocket_movement(gs, rocket: Plat.Rocket, test_only: bool):
	var new_pos = rocket.position + rocket.direction * Plat.ROCKET_SPEED
	if !test_only && Rect2Col.rect_collides_with_tile_map(
		Rect2(new_pos, rocket.size),
		gs.chunks,
		Plat.CHUNK_WIDTH_BLOCKS,
		Plat.CHUNK_HEIGHT_BLOCKS,
		Plat.BLOCK_LENGTH_PIXELS,
		Vector2.ZERO
	):
		despawn_actor(gs, rocket.actor_id)
		pass
	else:
		rocket.position = new_pos


static func system_rocket_time_to_live(gs: Plat.GameState, delta: float):
	for rocket: Plat.Rocket in gs.rockets:
		if rocket == null:
			continue
		if rocket.time_to_live_ms <= 0:
			despawn_actor(gs, rocket.actor_id)
		rocket.time_to_live_ms -= int(delta * 1000)


static func system_player_shoot_rocket(gs: Plat.GameState):
	for player: Plat.Player in gs.players:
		if player == null:
			continue
		if player.input.shoot == false:
			continue
		var player_center = player.position + Vector2(player.size.x, player.size.y) / 2
		var direction = player_center.direction_to(player.input.aim)

		var actor_id = spawn_rocket_server(gs, player_center, direction)
		if actor_id != -1:

			PlatWync.setup_sync_for_rocket_actor(gs, actor_id)

			# Simulating future movement to help client interpolation

			var actor: Plat.Actor = PlatPublic.get_actor(gs, actor_id)
			var rocket: Plat.Rocket = gs.rockets[actor.instance_id]
			var ball_spawn_data = Plat.RocketSpawnData.new()
			var old_rocket_pos = rocket.position

			PlatPublic.individual_rocket_movement(gs, rocket, true)

			ball_spawn_data.tick = WyncWrapper.wync_get_ticks(gs.wctx)
			ball_spawn_data.value1 = old_rocket_pos
			ball_spawn_data.value2 = rocket.position
			rocket.position = old_rocket_pos

			WyncThrottle.wync_entity_set_spawn_data(gs.wctx, actor_id, ball_spawn_data, 20)


static func player_input_additive(gs: Plat.GameState, player: Plat.Player, node2d: Node2D):
	player.input.movement_dir = Vector2(
		int(Input.is_action_pressed("p1_right")) - int(Input.is_action_pressed("p1_left")),
		int(Input.is_action_pressed("p1_down")) - int(Input.is_action_pressed("p1_up")),
	)
	#player.input.movement_dir = Vector2(signf(sin(Time.get_ticks_msec() / 100.0)), -1)
	player.input.shoot = player.input.shoot || Input.is_action_pressed("p1_mouse1")
	player.input.aim = PlatUtils.SCREEN_CORD_TO_GRID_CORD(gs, node2d.get_global_mouse_position())


static func player_input_reset(gs: Plat.GameState, player: Plat.Player):
	player.input.shoot = false


static func system_player_grid_events(gs: Plat.GameState, player: Plat.Player):
	if not Input.is_action_just_pressed("p1_mouse1"):
		return

	# get cursor grid position
	var cursor_grid_pos: Vector2i = Vector2i(
		floor(player.input.aim.x / Plat.BLOCK_LENGTH_PIXELS),
		floor(player.input.aim.y / Plat.BLOCK_LENGTH_PIXELS) +1,
	)

	# is it valid?
	if (cursor_grid_pos.x < 0 || cursor_grid_pos.x >= (Plat.CHUNK_AMOUNT * Plat.CHUNK_WIDTH_BLOCKS)
	|| cursor_grid_pos.y < 0 || cursor_grid_pos.y >= Plat.CHUNK_HEIGHT_BLOCKS):
		return

	print("debugmouse | mouse_grid_pos %s" % [cursor_grid_pos])

	# get mouse 1 event
	var event_data = Plat.EventPlayerBlockBreak.new()
	event_data.pos = cursor_grid_pos

	var event_id = WyncEventUtils.new_event_wrap_up(gs.wctx, Plat.EVENT_PLAYER_BLOCK_BREAK, event_data)
	WyncEventUtils.publish_global_event_as_client(gs.wctx, 0, event_id)


## Server runs events (aka inputs) from clients

static func system_server_events(gs: Plat.GameState):

	var channel_id = 0
	var server_wync_peer_id = 1

	var tick_start = gs.wctx.co_ticks.ticks - gs.wctx.max_age_user_events_for_consumption
	var tick_end = gs.wctx.co_ticks.ticks +1

	var something_happened = false
	for tick: int in range(tick_start, tick_end):

		var event_list: Array[int] = WyncWrapper.wync_get_events_from_channel_from_peer(
			gs.wctx, server_wync_peer_id, channel_id, tick)

		for event_id in event_list:
			var event := gs.wctx.events[event_id]

			# handle it
			Log.outc(gs.wctx, "event handling | tick(%s) handling server event %s" % [tick, event_id], Log.TAG_GAME_EVENT)
			handle_events(gs, event.data, server_wync_peer_id)
			WyncEventUtils.global_event_consume_tick(gs.wctx, server_wync_peer_id, channel_id, tick, event_id)
			something_happened = true

	if something_happened:
		Log.outc(gs.wctx, "event handling start (tick_curr %s)========================================" % [tick_end-1])

	"""
	for tick in range(tick_current - tick_event_range, tick_current):
		var event_id = WyncWrapper.wync_get_events_from_channel_from_peer(ctx, peer_id, tick)

		for event_id in event_list:
			var event = get_event(id)
			user_handle_event(event)

			wync_mark_event_as_consumed(ctx, event_id)
	"""


static func handle_events(gs: Plat.GameState, event_data: WyncEvent.EventData, peer_id: int):
	match event_data.event_type_id:
		Plat.EVENT_PLAYER_BLOCK_BREAK:
			var data = event_data.event_data as Plat.EventPlayerBlockBreak
			grid_block_break(gs, data.pos)


static func grid_block_break(gs: Plat.GameState, block_pos: Vector2i):
	# block pos is valid
	if (block_pos.x < 0 || block_pos.x >= (Plat.CHUNK_AMOUNT * Plat.CHUNK_WIDTH_BLOCKS)
	|| block_pos.y < 0 || block_pos.y >= Plat.CHUNK_HEIGHT_BLOCKS
	):
		Log.errc(gs.wctx, "Invalid coordinates");
		return

	# downgrade block
	var chunk_id = floori(block_pos.x / (Plat.CHUNK_WIDTH_BLOCKS))
	var chunk := gs.chunks[chunk_id]

	block_pos.x = block_pos.x % Plat.CHUNK_WIDTH_BLOCKS
	var block: Plat.Block = chunk.blocks[block_pos.x][block_pos.y]
	var new_block_type = max(0, block.type -1)

	# downgrade block as delta event
	var event_data = Plat.EventDeltaBlockReplace.new()
	event_data.pos = block_pos
	event_data.block_type = new_block_type

	# get block prop id
	var blocks_prop_id = WyncUtils.entity_get_prop_id(gs.wctx, chunk.actor_id, "blocks")
	assert(blocks_prop_id != -1)

	# commit event to wync
	var event_id = WyncEventUtils.new_event_wrap_up(gs.wctx, Plat.EVENT_DELTA_BLOCK_REPLACE, event_data)
	var err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
		gs.wctx, blocks_prop_id, Plat.EVENT_DELTA_BLOCK_REPLACE, event_id)
	if err != OK:
		Log.errc(gs.wctx, "Couldn't push event prop(%s) err(%s)" % [blocks_prop_id, err])
		return

	# apply event
	err = WyncDeltaSyncUtils.merge_event_to_state_real_state(gs.wctx, blocks_prop_id, event_id)
	if err != OK:
		Log.errc(gs.wctx, "Couldn't apply event prop(%s) err(%s)" % [blocks_prop_id, err])
