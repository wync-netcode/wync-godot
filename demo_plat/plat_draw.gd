class_name PlatDraw


static func draw_game(canvas: Node2D, gs: Plat.GameState):
	if gs.net.is_client:
		draw_block_grid(canvas, gs, gs.camera_offset)
		pass
	else:
		draw_block_grid(canvas, gs, gs.camera_offset + Vector2(0, 300))
	draw_box_trails(canvas, gs, gs.camera_offset)
	draw_balls(canvas, gs, gs.camera_offset)
	draw_players(canvas, gs, gs.camera_offset, not gs.net.is_client)
	draw_rockets(canvas, gs, gs.camera_offset)
	draw_ray_trails(canvas, gs, gs.camera_offset)
	draw_particles(canvas, gs, gs.camera_offset)


static func draw_block_grid(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var x_offset = offset.x
	var y_offset = offset.y
	var block_rect: Rect2
	
	for k in range(Plat.CHUNK_AMOUNT):
		var chunk := gs.chunks[k]
		var odd_chunk = WyncMisc.fast_modulus(k, 2) == 0

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
					(-j-1) * Plat.BLOCK_LENGTH_PIXELS + y_offset,
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
		ball_rect = Rect2(v_to_draw(ball.position + Vector2(-ball.size.x/2, ball.size.y/2), offset), ball.size)
		canvas.draw_rect(ball_rect, color, true, -1, true)
		ball_rect = Rect2(ball_rect.position.x +1, ball_rect.position.y +1, ball_rect.size.x -2, ball_rect.size.y -2)
		canvas.draw_rect(ball_rect, Color.BLACK, true, -1, true)
		ball_rect = Rect2(ball_rect.position.x +1, ball_rect.position.y +1, ball_rect.size.x -2, ball_rect.size.y -2)
		canvas.draw_rect(ball_rect, color, true, -1, true)


static func draw_players(canvas: Node2D, gs: Plat.GameState, offset: Vector2i, real_pos: bool):
	var rect: Rect2
	var color = Color.PINK
	var draw_pos: Vector2
	for player: Plat.Player in gs.players:
		if player == null:
			continue
		draw_pos = player.position if real_pos else player.visual_position

		rect = Rect2(v_to_draw(draw_pos +Vector2(-player.size.x/2, player.size.y/2), offset), player.size)
		canvas.draw_rect(rect, color, true, -1, true)
		rect = Rect2(rect.position.x +1, rect.position.y +1, rect.size.x -2, rect.size.y -2)
		canvas.draw_rect(rect, Color.BLACK, true, -1, true)
		rect = Rect2(rect.position.x +1, rect.position.y +1, rect.size.x -2, rect.size.y -2)
		canvas.draw_rect(rect, color, true, -1, true)


static func draw_rockets(canvas: Node2D, gs: Plat.GameState, offset: Vector2i):
	var rect: Rect2
	var color = Color.GOLD if !gs.net.is_client else Color.LIGHT_YELLOW
	for rocket: Plat.Rocket in gs.rockets:
		if rocket == null:
			continue
		rect = Rect2(v_to_draw(rocket.position + Vector2(-rocket.size.x/2, rocket.size.y/2), offset), rocket.size)
		canvas.draw_rect(rect, color, true, -1, true)
		rect = Rect2(rect.position.x +1, rect.position.y +1, rect.size.x -2, rect.size.y -2)
		canvas.draw_rect(rect, Color.BLACK, true, -1, true)
		rect = Rect2(rect.position.x +1, rect.position.y +1, rect.size.x -2, rect.size.y -2)
		canvas.draw_rect(rect, color, true, -1, true)


static func draw_box_trails(canvas: Node2D, gs: Plat.GameState, offset: Vector2, size: Vector2 = Vector2.ZERO):

	var default_trail_size = Vector2(round(Plat.BLOCK_LENGTH_PIXELS * 0.66), 10)
	var trail_rect = Rect2()
	var color = Color.RED

	for trail: Plat.Trail in gs.box_trails:

		trail_rect.size = default_trail_size if trail.size == Vector2.ZERO else trail.size
		trail_rect.position = Vector2(trail.position.x -trail_rect.size.x/2, -trail.position.y -trail_rect.size.y/2) + offset

		color.h = trail.hue
		canvas.draw_rect(trail_rect, color, false)


static func draw_ray_trails(canvas: Node2D, gs: Plat.GameState, offset: Vector2):
	var color = Color.RED
	for trail: Plat.RayTrail in gs.ray_trails:
		color.h = trail.hue
		canvas.draw_line(Vector2(trail.from.x, -trail.from.y) + offset, Vector2(trail.to.x, -trail.to.y) + offset, color, -1, false)


static func draw_particles(canvas: Node2D, gs: Plat.GameState, offset: Vector2):
	var color = Color.RED
	var size: Vector2

	for particle: Plat.Particle in gs.particles:
		color.h = particle.hue
		size = Vector2.ONE * 3 * particle.scale

		for i in range(particle.particle_amount):

			var angle = (2 * PI) * (1.0 / particle.particle_amount * i + particle.rotation)
			var pos = particle.pos - size/2 + Vector2.from_angle(angle) * (particle.tick_max_duration - particle.tick_duration)

			canvas.draw_rect(Rect2(v_to_draw(pos, offset), size), color, true, -1, true)

		canvas.draw_circle(v_to_draw(particle.pos, offset), 1.2, Color.BLACK, true, -1, true)
		canvas.draw_circle(v_to_draw(particle.pos, offset), 0.8, Color.WHITE, true, -1, true)


## Transforms vector from internal cords to godot draw cords
static func v_to_draw(v: Vector2, offset: Vector2) -> Vector2:
	return Vector2(v.x, -v.y) + offset
