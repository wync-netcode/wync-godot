class_name PlatPrivate


static func initialize_game_state(gs: Plat.GameState):

	gs.i_control_player_id = -1

	gs.actors.resize(Plat.ACTOR_AMOUNT)
	gs.balls.resize(Plat.BALL_AMOUNT)
	gs.players.resize(Plat.PLAYER_AMOUNT)
	gs.chunks.resize(Plat.CHUNK_AMOUNT)
	gs.rockets.resize(Plat.ROCKET_AMOUNT)
	gs.camera_offset = Vector2i(
		10,
		(Plat.CHUNK_HEIGHT_BLOCKS + 3) * Plat.BLOCK_LENGTH_PIXELS,
	)

	# chunks

	for k in range(Plat.CHUNK_AMOUNT):

		var chunk = Plat.Chunk.new()
		chunk.actor_id = Plat.CHUNK_ACTOR_ID_RANGE_START + k
		gs.chunks[k] = chunk
		PlatPublic.spawn_actor(gs, chunk.actor_id, Plat.ACTOR_TYPE_CHUNK, k)

		# fill

		chunk.blocks.resize(Plat.CHUNK_WIDTH_BLOCKS)
		chunk.position = k

		for i in range(Plat.CHUNK_WIDTH_BLOCKS):
			var vertical = chunk.blocks[i] as Array[Plat.Block]
			vertical.resize(Plat.CHUNK_HEIGHT_BLOCKS)

			for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
				var block = Plat.Block.new()
				vertical[j] = block



static func generate_world(gs: Plat.GameState):

	for k in range(Plat.CHUNK_AMOUNT):
		var chunk := gs.chunks[k]
		for i in range(Plat.CHUNK_WIDTH_BLOCKS):
			var x = k * Plat.CHUNK_WIDTH_BLOCKS + i
			for y in range(Plat.CHUNK_HEIGHT_BLOCKS):
				var block = chunk.blocks[i][y] as Plat.Block

				var sinus_value = sin(x / 2.0) * 1.2 + 5
				print(x, " ", sin(x), " ", sinus_value)
				if y < sinus_value:
					block.type = Plat.BLOCK_TYPE_DIRT
				else:
					block.type = Plat.BLOCK_TYPE_AIR

				if y <= 0:
					block.type = Plat.BLOCK_TYPE_IRON

	# walls
	var chunk := gs.chunks[0]
	for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
		var block = chunk.blocks[0][j] as Plat.Block
		block.type = Plat.BLOCK_TYPE_GOLD

	chunk = gs.chunks[Plat.CHUNK_AMOUNT-1]
	for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
		var block = chunk.blocks[Plat.CHUNK_WIDTH_BLOCKS-1][j] as Plat.Block
		block.type = Plat.BLOCK_TYPE_GOLD

	# ceiling
	for i in range(Plat.CHUNK_AMOUNT):
		chunk = gs.chunks[i]
		for j in range(Plat.CHUNK_WIDTH_BLOCKS):
			var block = chunk.blocks[j][Plat.CHUNK_HEIGHT_BLOCKS-1] as Plat.Block
			block.type = Plat.BLOCK_TYPE_GOLD



## chunk full snapshot
static func duplicate_chunk_blocks(chunk: Plat.Chunk) -> Array[Array]:
	var blocks: Array[Array] = []

	for k in range(Plat.CHUNK_AMOUNT):
		blocks.resize(Plat.CHUNK_WIDTH_BLOCKS)

		for i in range(Plat.CHUNK_WIDTH_BLOCKS):
			var vertical = blocks[i] as Array[Plat.Block]
			vertical.resize(Plat.CHUNK_HEIGHT_BLOCKS)

			for j in range(Plat.CHUNK_HEIGHT_BLOCKS):
				var chunk_block = (chunk.blocks[i][j] as Plat.Block)
				var block = Plat.Block.new()
				block.type = chunk_block.type
				vertical[j] = block

	return blocks
