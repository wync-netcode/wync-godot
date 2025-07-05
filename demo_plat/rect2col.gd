extends Node
class_name Rect2Col # rename to plat_physics.gd?


static func rect_collides_with_tile_map(
	rect: Rect2,
	chunks: Array[Plat.Chunk],
	chunk_width_blocks: int,
	chunk_height_blocks: int,
	block_length_pixels: int,
	chunks_offset: Vector2,
	) -> bool:
			
	# convert to the tile coordinates system
	var corner_topleft  = rect.position + Vector2(0, rect.size.y)- chunks_offset
	var corner_botright = rect.position + Vector2(rect.size.x, 0) - chunks_offset
	
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


## Note: No inside collisions, for that check point in AABB function
## @returns: Vector2 if collided, null if not collided
static func AABB_ray_intersects(origin: Vector2, dir: Vector2, box: Rect2) -> Variant:
	if origin == dir: return null
	var x_axis = box.position.x - box.size.x/2 * (1 if dir.x > 0 else -1)
	var y_axis = box.position.y - box.size.y/2 * (1 if dir.y > 0 else -1)
	var m      = INF      if dir.x == 0 else dir.y / dir.x
	var b      = 0.0      if dir.x == 0 else origin.y - m * origin.x
	var x_cast = origin.x if dir.x == 0 else (y_axis - b) / m
	var y_cast = m * x_axis + b
	return Vector2(x_axis, y_cast) if (y_cast >= box.position.y - box.size.y/2 && y_cast <= box.position.y + box.size.y/2)  else Vector2(x_cast, y_axis) if (x_cast >= box.position.x - box.size.x/2 && x_cast <= box.position.x + box.size.x/2) else null


## @arg dir: must be a unit vector
## @returns float: >= 0 collision; -1 no collision
static func AABB_raycast (origin: Vector2, dir: Vector2, box: Rect2) -> float:
	var coll_point = AABB_ray_intersects(origin, dir, box)
	if coll_point == null: return -1
	var dot_b = coll_point - origin
	var distance = dir.x * dot_b.x + dir.y * dot_b.y
	return distance


static func AABB_has_point (box: Rect2, point: Vector2) -> bool:
	point += box.size/2
	return point.x >= box.position.x && point.x <= box.position.x + box.size.x &&\
		point.y >= box.position.y && point.y <= box.position.y + box.size.y
