extends Node
class_name Rect2Col


static func rect_collides_with_tile_map(
	rect: Rect2,
	chunks: Array[Plat.Chunk],
	chunk_width_blocks: int,
	chunk_height_blocks: int,
	block_length_pixels: int,
	chunks_offset: Vector2,
	) -> bool:
			
	# convert to the tile coordinates system
	var corner_topleft  = rect.position - chunks_offset
	var corner_botright = rect.position + Vector2(rect.size.x, -rect.size.y) - chunks_offset
	
	var rect_topleft_pos: Vector2i = Vector2i(
		floor(corner_topleft.x / block_length_pixels),
		floor(corner_topleft.y / block_length_pixels) +1,
	)
	var rect_botright_pos: Vector2i = Vector2i(
		floor(corner_botright.x / block_length_pixels),
		floor(corner_botright.y / block_length_pixels) +1,
	)
	var transformed_rect = Rect2(
		corner_topleft.x / block_length_pixels,
		corner_topleft.y / block_length_pixels + 1,
		rect.size.x / block_length_pixels,
		rect.size.y / block_length_pixels,
	)
	transformed_rect.position.y -= transformed_rect.size.y

	for i in range(rect_topleft_pos.x, rect_botright_pos.x+1):
		if (i < 0 || i >= chunks.size() * chunk_width_blocks):
			continue
		var chunk_id: int = i / chunk_width_blocks
		var block_pos_x: int = i - chunk_id * chunk_width_blocks

		for j in range(rect_botright_pos.y, rect_topleft_pos.y +1):
			if (j < 0 || j >= chunk_height_blocks):
				continue

			var block = chunks[chunk_id].blocks[block_pos_x][j]
			if not PlatPublic.block_is_solid(block):
				continue

			var block_rect = Rect2(i, j, 1, 1)
			if transformed_rect.intersects(block_rect):
				return true
						
	return false
