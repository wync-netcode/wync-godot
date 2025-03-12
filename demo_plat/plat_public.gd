class_name PlatPublic


static func spawn_ball(gs: Plat.GameState, origin: Vector2):
	var ball = Plat.Ball.new()
	ball.position = origin
	ball.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 1.5)
	ball.velocity.x = 3
	gs.balls.append(ball)


static func spawn_player(gs: Plat.GameState, origin: Vector2):
	var player = Plat.Player.new()
	player.position = origin
	player.size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 1.5)
	player.input = Plat.PlayerInput.new()
	gs.players.append(player)


static func block_is_solid(block: Plat.Block) -> bool:
	return block.type != Plat.BLOCK_TYPE_AIR


static func system_ball_movement(gs: Plat.GameState, node2d: Node2D):
	for ball: Plat.Ball in gs.balls:
		# velocity
		ball.velocity.y -= Plat.BALL_GRAVITY
		#ball.velocity.x = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.x)) * sign(ball.velocity.x)
		#ball.velocity.y = min(Plat.BALL_MAX_SPEED, abs(ball.velocity.y)) * sign(ball.velocity.y)
		var new_pos = ball.position + ball.velocity

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


static func system_player_movement(gs: Plat.GameState, delta: float):
	for player: Plat.Player in gs.players:
		
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


static func player_input_additive(gs: Plat.GameState, player: Plat.Player, node2d: Node2D):
	player.input.movement_dir = Vector2(
		int(Input.is_action_pressed("p1_right")) - int(Input.is_action_pressed("p1_left")),
		int(Input.is_action_pressed("p1_down")) - int(Input.is_action_pressed("p1_up")),
	)
	player.input.shoot = player.input.shoot || Input.is_action_pressed("p1_mouse1")
	player.input.aim = node2d.get_global_mouse_position()


static func player_input_reset(gs: Plat.GameState, player: Plat.Player, node2d: Node2D):
	player.input.shoot = false
