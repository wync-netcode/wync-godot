class_name PlatPublic


static func get_nete_peer(gs: Plat.GameState, nete_peer_id: int) -> Plat.Server.Peer:
	for peer: Plat.Server.Peer in gs.net.server.peers:
		if peer.peer_id == nete_peer_id:
			return peer
	return null


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
	if WyncTrack.is_entity_tracked(gs.wctx, actor_id):
		WyncTrack.untrack_entity(gs.wctx, actor_id)
	
	Log.outc(gs.wctx, "spawn, despawned entity %s" % [actor_id])


## @returns int. actor_id or -1
static func spawn_ball_server(gs: Plat.GameState, origin: Vector2, behaviour: int) -> int:
	var actor_id = actor_find_available_id(gs)
	gs.actors_added_or_deleted = true
	return spawn_ball(gs, origin, actor_id, behaviour)


## @returns int. actor_id or -1
static func spawn_ball(gs: Plat.GameState, origin: Vector2, actor_id: int, behaviour: int) -> int:
	var ball_id = ball_find_available_id(gs)
	if actor_id == -1 || ball_id == -1:
		return -1

	var ball = Plat.Ball.new()
	ball.actor_id = actor_id
	ball.position = origin
	ball.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 0.66)
	ball.velocity.x = Plat.BALL_MAX_SPEED
	ball.behaviour = behaviour
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


static func spawn_box_trail(gs: Plat.GameState, origin: Vector2, hue: float, tick_duration: int):
	var trail = Plat.Trail.new()
	trail.position = origin
	trail.size = Vector2.ZERO
	trail.hue = hue
	trail.tick_duration = tick_duration
	gs.box_trails.append(trail)


static func spawn_box_trail_size(gs: Plat.GameState, origin: Vector2, size: Vector2, hue: float, tick_duration: int):
	var trail = Plat.Trail.new()
	trail.position = origin
	trail.size = size
	trail.hue = hue
	trail.tick_duration = tick_duration
	gs.box_trails.append(trail)


static func spawn_ray_trail(gs: Plat.GameState, from: Vector2, to: Vector2, hue: float, tick_duration: int):
	var ray = Plat.RayTrail.new()
	ray.from = from
	ray.to = to
	ray.hue = hue
	ray.tick_duration = tick_duration
	gs.ray_trails.append(ray)


static func spawn_particle(gs: Plat.GameState, pos: Vector2, scale: float, hue: float, particle_amount: int, rotation: float):
	var particle = Plat.Particle.new()
	particle.pos = pos
	particle.scale = scale
	particle.hue = hue
	particle.particle_amount = particle_amount
	particle.rotation = rotation
	particle.tick_duration = 15
	particle.tick_max_duration = particle.tick_duration
	particle.rotation = randf()
	gs.particles.append(particle)
	

static func system_trail_lives(gs: Plat.GameState):

	for trail_id: int in range(gs.box_trails.size()-1, -1, -1):
		var trail := gs.box_trails[trail_id]
		if trail == null:
			gs.box_trails.remove_at(trail_id)
		if trail.tick_duration <= 0:
			gs.box_trails.remove_at(trail_id)
		trail.tick_duration -= 1

	for trail_id: int in range(gs.ray_trails.size()-1, -1, -1):
		var trail := gs.ray_trails[trail_id]
		if trail == null:
			gs.ray_trails.remove_at(trail_id)
		if trail.tick_duration <= 0:
			gs.ray_trails.remove_at(trail_id)
		trail.tick_duration -= 1

	for id: int in range(gs.particles.size()-1, -1, -1):
		var particle := gs.particles[id]
		if particle == null:
			gs.particles.remove_at(id)
		if particle.tick_duration <= 0:
			gs.particles.remove_at(id)
		particle.tick_duration -= 1


static func block_is_solid(block: Plat.Block) -> bool:
	return block.type != Plat.BLOCK_TYPE_AIR


static func system_ball_movement(gs: Plat.GameState, delta: float):
	var curr_tick = Engine.get_physics_frames()
	for ball: Plat.Ball in gs.balls:
		if ball == null:
			continue

		var new_pos: Vector2

		match ball.behaviour:
			Plat.BALL_BEHAVIOUR_STATIC:
				continue
			Plat.BALL_BEHAVIOUR_SINE:
				new_pos = ball.position + Vector2(ball.velocity.x, 100*sin(curr_tick/15.0)) * delta
				pass
			Plat.BALL_BEHAVIOUR_LINE:
				new_pos = ball.position + Vector2(ball.velocity.x, 0) * delta
				pass
			Plat.BALL_BEHAVIOUR_BUNNY:
				ball.velocity.y -= Plat.BALL_GRAVITY * delta
				new_pos = ball.position + ball.velocity * delta
				pass

		# velocity
		#ball.velocity.y -= Plat.BALL_GRAVITY * delta
		#ball.velocity.x = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.x)) * sign(ball.velocity.x)
		#ball.velocity.y = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.y)) * sign(ball.velocity.y)
		#var new_pos = ball.position + Vector2(ball.velocity.x, ball.velocity.y) * delta
		#var new_pos = ball.position + Vector2(ball.velocity.x, 0)
		#var new_pos = ball.position + Vector2(ball.velocity.x, 100*sin(curr_tick/15.0)) * delta

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

		if ball.position.x > 800: ball.position.x = 300


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
		if player.input.action1 == false:
			continue
		var player_center = player.position
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

			ball_spawn_data.tick = WyncClock.wync_get_ticks(gs.wctx)
			ball_spawn_data.value1 = old_rocket_pos
			ball_spawn_data.value2 = rocket.position
			rocket.position = old_rocket_pos

			WyncThrottle.wync_entity_set_spawn_data(gs.wctx, actor_id, ball_spawn_data, 20)


static func system_players_shoot_bullet_timewarp_ping_based(gs: Plat.GameState):

	for nete_peer: Plat.Server.Peer in gs.net.server.peers:
		if !nete_peer.already_setup:
			continue
		var actor := PlatPublic.get_actor(gs, nete_peer.player_actor_id)
		var player := gs.players[actor.instance_id]
		if player == null:
			continue
		if player.input.action2 == false:
			continue
		var wync_peer_id = WyncJoin.get_wync_peer_id_from_nete_peer_id(gs.wctx, nete_peer.peer_id)
		if wync_peer_id == -1:
			continue

		handle_player_shoot_timewarp_ping_based(gs, wync_peer_id, gs.wctx.co_ticks.ticks)


static func system_player_shoot_bullet(
	gs: Plat.GameState, player: Plat.Player, ray_hue: float = 0):

	if player == null:
		return

	var box = Rect2()
	var ray_length = 400
	var origin = player.position
	var direction = origin.direction_to(player.input.aim)

	for ball: Plat.Ball in gs.balls:
		if ball == null:
			continue
		box.position = ball.position
		box.size = ball.size

		#if debug_color: origin += Vector2(2,2)

		spawn_ray_trail(gs, origin, origin + direction * ray_length, ray_hue, 1)

		var coll = Rect2Col.AABB_raycast(origin, direction, box)
		if coll.z < 0:
			continue

		spawn_particle(gs, Vector2(coll.x, coll.y), 1, ray_hue, 5, 0)


static func player_input_additive(gs: Plat.GameState, player: Plat.Player, node2d: Node2D):
	var on_frame: bool = Engine.get_physics_frames() % 2 == 0
	player.input.movement_dir = Vector2(
		int(Input.is_action_pressed("p1_right")) - int(Input.is_action_pressed("p1_left")),
		int(Input.is_action_pressed("p1_down")) - int(Input.is_action_pressed("p1_up")),
	)
	#player.input.movement_dir = Vector2(signf(sin(Time.get_ticks_msec() / 100.0)), -1)
	player.input.action1 = player.input.action1 || (Input.is_action_pressed("p1_mouse1") && on_frame)
	player.input.action2 = player.input.action2 || (Input.is_action_pressed("p1_mouse2") && on_frame)
	player.input.action3 = player.input.action3 || (Input.is_action_pressed("p1_mouse3") && on_frame)
	player.input.aim = PlatUtils.SCREEN_CORD_TO_GRID_CORD(gs, node2d.get_global_mouse_position())


static func player_input_reset(_gs: Plat.GameState, player: Plat.Player):
	player.input.action1 = false
	player.input.action2 = false
	player.input.action3 = false


static func system_player_grid_events(gs: Plat.GameState, player: Plat.Player):
	if not Input.is_action_just_pressed("p1_mouse1"):
		return

	# get cursor grid position
	var cursor_grid_pos: Vector2i = Vector2i(
		floor(player.input.aim.x / Plat.BLOCK_LENGTH_PIXELS),
		floor(player.input.aim.y / Plat.BLOCK_LENGTH_PIXELS),
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


static func system_player_timewarp_shoot_event(gs: Plat.GameState, player: Plat.Player):

	# ping based
	if player.input.action2:
		PlatWync.debug_draw_timewarped_state(gs, [18], 0.8)
		player.input.action2 = false
		return

	# event based
	if not player.input.action3:
		return
	player.input.action3 = false

	var ctx = gs.wctx

	# poll once per tick

	if player.last_tick_polled == ctx.co_ticks.ticks:
		Log.outc(ctx, "skipping tick %s" % ctx.co_ticks.ticks)
		return
	player.last_tick_polled = ctx.co_ticks.ticks

	# build and queue event

	var event_data = Plat.EventPlayerShootTimewarp.new()
	event_data.last_tick_rendered_left = ctx.co_ticks.last_tick_rendered_left
	event_data.lerp_delta_ms = ctx.co_ticks.minimum_lerp_fraction_accumulated_ms

	var event_id = WyncEventUtils.new_event_wrap_up(gs.wctx, Plat.EVENT_PLAYER_SHOOT_TIMEWARP, event_data)
	WyncEventUtils.publish_global_event_as_client(gs.wctx, 0, event_id)

	PlatWync.debug_draw_timewarped_state(gs, [18], 0.6)

	Log.outc(gs.wctx, "debugtimewarpevent | sending event (left_tick %s lerp_delta %.2f) server_tick %s last pred %s" % [event_data.last_tick_rendered_left, event_data.lerp_delta_ms, ctx.co_ticks.server_ticks, ctx.current_predicted_tick])


static func system_client_simulate_own_events(gs: Plat.GameState, tick: int):

	var EVENTS_TO_PREDICT = [Plat.EVENT_PLAYER_BLOCK_BREAK]
	var channel_id = 0
	var wync_peer_id = gs.wctx.my_peer_id

	#var event_list: Array[int] = WyncWrapper.wync_get_events_from_channel_from_peer(
		#gs.wctx, wync_peer_id, channel_id, tick)
	# TODO: wrap on a new function or fix ^^^
	var event_list: Array = gs.wctx.peer_has_channel_has_events[wync_peer_id][channel_id]

	for event_id in event_list:
		var event := gs.wctx.events[event_id]

		if event.data.event_type_id not in EVENTS_TO_PREDICT:
			continue

		# handle it
		Log.outc(gs.wctx, "debugrela event handling | tick(%s) handling peer%s event %s" % [tick, wync_peer_id, event_id])
		handle_events(gs, event.data, wync_peer_id, tick)


## Server runs events (aka inputs) from clients

static func system_server_events(gs: Plat.GameState):

	var channel_id = 0
	var server_wync_peer_id = 1

	var tick_start = gs.wctx.co_ticks.ticks - gs.wctx.max_age_user_events_for_consumption
	var tick_end = gs.wctx.co_ticks.ticks +1

	for tick: int in range(tick_start, tick_end):

		var event_list: Array[int] = WyncEventUtils.wync_get_events_from_channel_from_peer(
			gs.wctx, server_wync_peer_id, channel_id, tick)

		for event_id in event_list:
			var event := gs.wctx.events[event_id]

			# handle it
			#Log.outc(gs.wctx, "event handling | tick(%s) handling peer%s event %s" % [tick, server_wync_peer_id, event_id], Log.TAG_GAME_EVENT)
			handle_events(gs, event.data, server_wync_peer_id, tick)
			WyncEventUtils.global_event_consume_tick(gs.wctx, server_wync_peer_id, channel_id, tick, event_id)


	# debug show events that were ommited
	# -----
	var ignored_events = 0
	for tick: int in range(tick_start-100, tick_start):
		var event_list: Array[int] = WyncEventUtils.wync_get_events_from_channel_from_peer(
			gs.wctx, server_wync_peer_id, channel_id, tick)
		ignored_events += event_list.size()
	if ignored_events != 0: Log.errc(gs.wctx, "debugevents, Found %s ignored events" % [ignored_events])
	# -----


static func handle_events(gs: Plat.GameState, event_data: WyncEvent.EventData, wync_peer_id: int, tick: int):
	match event_data.event_type_id:
		Plat.EVENT_PLAYER_BLOCK_BREAK:
			var data = event_data.event_data as Plat.EventPlayerBlockBreak
			grid_block_break(gs, data.pos)
		Plat.EVENT_PLAYER_SHOOT_TIMEWARP:
			var data = event_data.event_data as Plat.EventPlayerShootTimewarp
			handle_player_shoot_timewarp(gs, data, wync_peer_id, tick, 0.3)
			# Note: see plat_server main loop for _ping based timewarp_
		_:
			Log.errc(gs.wctx, "Event not recognized %s" % [event_data.event_type_id])


static func grid_block_break(gs: Plat.GameState, block_pos: Vector2i):
	# debug code: desync delta prop
	if gs.wctx.is_client:
		block_pos.x -= 1

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
	var blocks_prop_id = WyncTrack.entity_get_prop_id(gs.wctx, chunk.actor_id, "blocks")
	assert(blocks_prop_id != -1)

	#Log.outc(gs.wctx, "debugrela prop %s last predicted tick %s" % [chunk.actor_id, gs.wctx.entity_last_predicted_tick[chunk.actor_id]])
	#Log.outc(gs.wctx, "debugrela, curr_pred_tick %s delta props do not predict these %s" % [gs.wctx.current_predicted_tick, gs.wctx.global_entity_ids_to_not_predrict])

	# allowed to predict this entity?
	# TODO: make a wrapper maybe?
	if gs.wctx.is_client && !gs.wctx.global_entity_ids_to_predict.has(chunk.actor_id):
		Log.outc(gs.wctx, "debugrela DENIED delta change, prop(%s)" % [blocks_prop_id])
		return

	# commit event to wync
	var event_id = WyncEventUtils.new_event_wrap_up(gs.wctx, Plat.EVENT_DELTA_BLOCK_REPLACE, event_data)
	var err = WyncDeltaSyncUtils.delta_prop_push_event_to_current(
		gs.wctx, blocks_prop_id, Plat.EVENT_DELTA_BLOCK_REPLACE, event_id)
	if err != OK:
		Log.errc(gs.wctx, "debugrela Couldn't push event prop(%s) err(%s)" % [blocks_prop_id, err])
		return

	# apply event
	err = WyncDeltaSyncUtils.merge_event_to_state_real_state(gs.wctx, blocks_prop_id, event_id)
	if err != OK:
		Log.errc(gs.wctx, "debugrela Couldn't apply event prop(%s) err(%s)" % [blocks_prop_id, err])
		return

	Log.outc(gs.wctx, "debugrela applied successfully grid_block_break")


static func handle_player_shoot_timewarp_ping_based(gs: Plat.GameState, wync_peer_id: int, origin_tick: int):

	# * approximates what tick the client saw based on his ping + lerp configuration
	# * this method can support sub-tick timing but it's an approximation
	
	var ctx = gs.wctx
	var frame_ms = 1000.0 / ctx.physic_ticks_per_second
	var peer_latency_info := ctx.peer_latency_info[wync_peer_id] as WyncCtx.PeerLatencyInfo
	var client_info := ctx.client_has_info[wync_peer_id] as WyncClientInfo

	# predicted_tick_offset = ceil(peer_latency_info.latency_stable_ms / frame_ms) + 2
	# tick_target = origin_tick -latency_stable -lerp_ticks -predicted_tick_offset

	var tick_target = origin_tick -  ceil(float(peer_latency_info.latency_stable_ms * 2 + client_info.lerp_ms)/frame_ms) - 2
	Log.outc(ctx, "debugtimewarp, ping based. origin_tick %s target %s" % [origin_tick, tick_target])

	var event_data := Plat.EventPlayerShootTimewarp.new()
	event_data.last_tick_rendered_left = tick_target
	event_data.lerp_delta_ms = 0
	handle_player_shoot_timewarp(gs, event_data, wync_peer_id, origin_tick, 0)


## temporarily resets props to a previous state to perform physics checks
## @arg origin_tick: int. tick from which this event originates from
static func handle_player_shoot_timewarp(
	gs: Plat.GameState,
	data: Plat.EventPlayerShootTimewarp,
	wync_peer_id: int,
	origin_tick: int,
	ray_hue: float
	):

	var ctx = gs.wctx
	if data is not Plat.EventPlayerShootTimewarp:
		Log.errc(ctx, "timewarp, wrong data type %s" % [data])
		return

	if wync_peer_id == 0:
		Log.errc(ctx, "timewarp, wync_peer_id == 0, server event, ignoring")
		return

	var co_ticks = ctx.co_ticks
	var client_info := ctx.client_has_info[wync_peer_id] as WyncClientInfo
	var lerp_ms: int = client_info.lerp_ms
	var tick_left: int = data.last_tick_rendered_left
	var lerp_delta_ms: float = data.lerp_delta_ms
	var frame_ms: float = 1000.0 / ctx.physic_ticks_per_second
	
	# Notes for anti-cheat measures:
	# * One could add some guards like "if lerp_delta < 0 || lerp_delta > 1"
	# * Range allowed:
	# * (1) Low. No limit, current implementation
	# * (2) Middle. Allow ticks in the range of the _prob prop rate_
	# * (3) High. Only allow ranges of 1 tick (the small range defined by the
	#   client's: latency + lerp_ms + last_packet_sent)

	if ((tick_left <= co_ticks.ticks - ctx.max_tick_history_timewarp) ||
		(tick_left > co_ticks.ticks)
		):
		Log.warc(ctx, "debugtimewarp, tick_left out of range (%s) skipping" % [tick_left])
		return
	
	Log.outc(ctx, "debugtimewarp, client shoots at tick_left %d | lerp_delta %s | lerp_ms %s | tick_diff %s" % [ tick_left, lerp_delta_ms, lerp_ms, co_ticks.ticks - tick_left ])


	# 1. save current state (for selcted timewarpable props)

	WyncWrapper.extract_data_to_tick_for_regular_state_props(
		ctx, co_ticks.ticks, ctx.filtered_regular_timewarpable_prop_ids)

	# 2. set previous state

	var non_interpolable: Array[int] = []
	for prop_id in ctx.filtered_regular_timewarpable_prop_ids:
		if prop_id not in ctx.filtered_regular_timewarpable_interpolable_prop_ids:
			non_interpolable.append(prop_id)

	var tick_origin_target = tick_left + floor(lerp_delta_ms/frame_ms) 
	if tick_origin_target != ctx.co_ticks.ticks:
		WyncStateSet.wync_reset_state_to_saved_absolute(
			ctx, non_interpolable, tick_left + floor(lerp_delta_ms/frame_ms) )
	WyncLerp.wync_reset_state_to_interpolated_absolute(
		ctx, ctx.filtered_regular_timewarpable_interpolable_prop_ids, tick_left, lerp_delta_ms)

	# show debug trail
		
	for prop_id: int in ctx.filtered_regular_timewarpable_prop_ids:
		var prop := WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.name_id != "position":
			continue

		var getter = ctx.wrapper.prop_getter[prop_id]
		var user_ctx = ctx.wrapper.prop_user_ctx[prop_id]
		var position = getter.call(user_ctx)

		#WyncTrack.prop_get_entity(gs.wctx.

		PlatPublic.spawn_box_trail_size(gs, position, Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 0.66), 0.7, 1.5*60)

	# 2.1. optional: integrate physics

	# 3. do my physics checks

	# from peer get player actor

	var nete_peer_id = WyncJoin.get_nete_peer_id_from_wync_peer_id(ctx, wync_peer_id)
	assert(nete_peer_id != -1)
	var peer = PlatPublic.get_nete_peer(gs, nete_peer_id)
	assert(peer != null)
	var actor_id = peer.player_actor_id
	var actor: Plat.Actor = PlatPublic.get_actor(gs, actor_id)
	assert(actor.actor_type == Plat.ACTOR_TYPE_PLAYER)
	var player: Plat.Player = gs.players[actor.instance_id]
	assert(player != null)
	Log.outc(gs.wctx, "debugtimewarp, Player who shot is %s" % [player])

	# reset player props state to 'origin tick'

	var timewarpable_player_prop_ids: Array[int] = []
	var player_prop_ids: Array[int] = []
	player_prop_ids.append_array(WyncTrack.entity_get_prop_id_list(ctx, actor_id))
	for prop_id in player_prop_ids:
		if prop_id in ctx.filtered_regular_timewarpable_prop_ids:
			timewarpable_player_prop_ids.append(prop_id)

	WyncStateSet.wync_reset_state_to_saved_absolute(
		ctx, timewarpable_player_prop_ids, origin_tick)

	# then perform ray

	PlatPublic.system_player_shoot_bullet(gs, player, ray_hue)

	# 4. restore original state

	WyncStateSet.wync_reset_state_to_saved_absolute(
		ctx, ctx.filtered_regular_timewarpable_prop_ids, co_ticks.ticks)

	# 4.1. optional: integrate physics


static func debug_print_last_chunk(gs: Plat.GameState):
	var chunk: Plat.Chunk = gs.chunks[Plat.CHUNK_AMOUNT-1]
	var txt: String = ""

	for i in range(Plat.CHUNK_WIDTH_BLOCKS):
		var block: Plat.Block = chunk.blocks[i][Plat.CHUNK_HEIGHT_BLOCKS-1]
		txt += "%s," % [block.type]

	Log.outc(gs.wctx, "debugrela chunk info %s | %s" % [chunk.position, txt])
