class_name PlatDraw


static func draw_game(canvas: Node2D, gs: Plat.GameState):
	var draw_offset = Vector2i(
		10,
		Plat.CHUNK_HEIGHT_BLOCKS * 1.2 * Plat.BLOCK_LENGTH_PIXELS,
	)
	draw_block_grid(canvas, gs, draw_offset)
	draw_balls(canvas, gs, draw_offset)


static func draw_block_grid(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var x_offset = offset.x
	var y_offset = offset.y
	
	for k in range(Plat.CHUNK_AMOUNT):
		var chunk := gs.chunks[k]
		for i in range(Plat.CHUNK_WIDTH_BLOCKS):
			var x = k * Plat.CHUNK_WIDTH_BLOCKS + i
			for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
				var block = chunk.blocks[i][j] as Plat.Block
				var color = Color.WHITE
				var odd_chunk = false

				if block.type == Plat.BLOCK_TYPE_AIR:
					continue

				if WyncUtils.fast_modulus(k, 2) == 0:
					odd_chunk = true
					
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
				var block_rect = Rect2(
					x * Plat.BLOCK_LENGTH_PIXELS + x_offset,
					(-j) * Plat.BLOCK_LENGTH_PIXELS + y_offset,
					Plat.BLOCK_LENGTH_PIXELS,
					Plat.BLOCK_LENGTH_PIXELS
				)
				canvas.draw_rect(block_rect, color, true)
				canvas.draw_rect(block_rect, Color.BLACK, false)


static func draw_balls(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var ball_rect: Rect2
	var color = Color.WHITE
	for ball: Plat.Ball in gs.balls:
		ball_rect = Rect2(Vector2(ball.position.x, -ball.position.y) + Vector2(offset), ball.size)
		canvas.draw_rect(ball_rect, color, true)
		canvas.draw_rect(ball_rect, Color.BLACK, false)
