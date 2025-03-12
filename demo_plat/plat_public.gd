class_name PlatPublic


static func spawn_ball(gs: Plat.GameState, origin: Vector2):
	var ball = Plat.Ball.new()
	ball.position = origin
	ball.size = Vector2(10, 30)
	ball.velocity.x = 3
	gs.balls.append(ball)


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
