class_name PlatUtils


static func GRID_CORD(x: int, y: int) -> Vector2:
	return Vector2(x * Plat.BLOCK_LENGTH_PIXELS, y * Plat.BLOCK_LENGTH_PIXELS)


static func SCREEN_CORD_TO_GRID_CORD(gs: Plat.GameState, pos: Vector2) -> Vector2:
	return Vector2(pos.x -gs.camera_offset.x, -(pos.y -gs.camera_offset.y))
