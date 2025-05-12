class_name PlatDraw


static func draw_game(canvas: Node2D, gs: Plat.GameState):
	if not gs.net.is_client:
		draw_block_grid(canvas, gs, gs.camera_offset)
		pass
	else:
		draw_block_grid(canvas, gs, gs.camera_offset + Vector2(0, 300))
	draw_trails(canvas, gs, gs.camera_offset)
	draw_balls(canvas, gs, gs.camera_offset)
	draw_players(canvas, gs, gs.camera_offset, not gs.net.is_client)
	draw_rockets(canvas, gs, gs.camera_offset)


static func draw_block_grid(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var x_offset = offset.x
	var y_offset = offset.y
	var block_rect: Rect2
	
	for k in range(Plat.CHUNK_AMOUNT):
		var chunk := gs.chunks[k]
		var odd_chunk = WyncUtils.fast_modulus(k, 2) == 0

		for i in range(Plat.CHUNK_WIDTH_BLOCKS):
			var x = k * Plat.CHUNK_WIDTH_BLOCKS + i
			for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
				var block = chunk.blocks[i][j] as Plat.Block
				var color = Color.WHITE

				if block.type == Plat.BLOCK_TYPE_AIR:
					continue
					
				if odd_chunk:
					match block.type:
						Plat.BLOCK_TYPE_DIRT:
							color = Color.SADDLE_BROWN
						Plat.BLOCK_TYPE_IRON:
							color = Color.DARK_GRAY
						Plat.BLOCK_TYPE_GOLD:
							color = Color.GOLDENROD
				else:
					match block.type:
						Plat.BLOCK_TYPE_DIRT:
							color = Color.BROWN
						Plat.BLOCK_TYPE_IRON:
							color = Color.GRAY
						Plat.BLOCK_TYPE_GOLD:
							color = Color.GOLD

				# tile
				block_rect = Rect2(
					x * Plat.BLOCK_LENGTH_PIXELS + x_offset,
					(-j) * Plat.BLOCK_LENGTH_PIXELS + y_offset,
					Plat.BLOCK_LENGTH_PIXELS,
					Plat.BLOCK_LENGTH_PIXELS
				)
				canvas.draw_rect(block_rect, color, true)
				#canvas.draw_rect(block_rect, Color.BLACK, false)


static func draw_balls(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var ball_rect: Rect2
	var color = Color.WHITE
	for ball: Plat.Ball in gs.balls:
		if ball == null:
			continue
		ball_rect = Rect2(Vector2(ball.position.x, -ball.position.y -ball.size.y) + Vector2(offset), ball.size)
		canvas.draw_rect(ball_rect, color, true, -1, true)
		ball_rect = Rect2(ball_rect.position.x +1, ball_rect.position.y +1, ball_rect.size.x -2, ball_rect.size.y -2)
		canvas.draw_rect(ball_rect, Color.BLACK, true, -1, true)
		ball_rect = Rect2(ball_rect.position.x +1, ball_rect.position.y +1, ball_rect.size.x -2, ball_rect.size.y -2)
		canvas.draw_rect(ball_rect, color, true, -1, true)


static func draw_players(canvas: Node2D, gs: Plat.GameState, offset: Vector2i, real_pos: bool):
	var player_rect: Rect2
	var color = Color.PINK
	for player: Plat.Player in gs.players:
		if player == null:
			continue
		if real_pos:
			player_rect = Rect2(Vector2(player.position.x, -player.position.y -player.size.y) + Vector2(offset), player.size)
		else:
			player_rect = Rect2(Vector2(player.visual_position.x, -player.visual_position.y -player.size.y) + Vector2(offset), player.size)
		canvas.draw_rect(player_rect, color, true)
		player_rect = Rect2(player_rect.position.x +1, player_rect.position.y +1, player_rect.size.x -2, player_rect.size.y -2)
		canvas.draw_rect(player_rect, Color.BLACK, true)
		player_rect = Rect2(player_rect.position.x +1, player_rect.position.y +1, player_rect.size.x -2, player_rect.size.y -2)
		canvas.draw_rect(player_rect, color, true)


static func draw_rockets(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var rect: Rect2
	for rocket: Plat.Rocket in gs.rockets:
		if rocket == null:
			continue
		rect = Rect2(Vector2(rocket.position.x, -rocket.position.y -rocket.size.y) + Vector2(offset), rocket.size)
		canvas.draw_rect(rect, Color.GOLD, true)
		canvas.draw_rect(rect, Color.BLACK, false)


static func draw_trails(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var trail_rect = Rect2(Vector2.ZERO, Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), Plat.BLOCK_LENGTH_PIXELS * 1.5))
	trail_rect.size.y = 10
	var color = Color.RED
	for trail: Plat.Trail in gs.trails:
		trail_rect.position = Vector2(trail.position.x, -trail.position.y -trail_rect.size.y) + Vector2(offset)
		trail_rect.position.y += 10
		color.h = trail.hue
		canvas.draw_rect(trail_rect, color, false)
