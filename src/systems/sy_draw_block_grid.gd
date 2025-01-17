extends System
class_name SyDrawBlockGrid
const label: StringName = StringName("SyDrawBlockGrid")


func _ready():
	components = [CoBlockGrid.label]
	super()


func _draw() -> void:
	var world = ECS.find_world_up(self)
	var world_id = world.get_instance_id()
	
	if not ECS.world_systems.has(world_id) ||\
		not ECS.world_systems[world_id].has(label):
		return
	else:
		var _system = ECS.world_systems[world_id][label]
		if _system == null || !_system.enabled:
			return
	
	var entities = ECS.world_system_entities[world_id][label]
	for entity in entities:
		draw_block_grid(entity)
		return

const TILE_LENGTH_PIXELS = 30

func draw_block_grid(entity: Entity):
	var node2d = self as Node as Node2D
	var block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	if !block_grid:
		return
	var single_world = ECS.get_singleton_component(self, CoSingleWorld.label) as CoSingleWorld
	var x_offset = single_world.world_id * ((block_grid.LENGTH + 1) * TILE_LENGTH_PIXELS)
	
	for i in range(block_grid.LENGTH):
		for j in range(block_grid.LENGTH):
			# tile
			var block_rect = Rect2(
				i * TILE_LENGTH_PIXELS + x_offset,
				j * TILE_LENGTH_PIXELS,
				TILE_LENGTH_PIXELS,
				TILE_LENGTH_PIXELS
			)
			node2d.draw_rect(block_rect, Color.BLACK, false)
			
			# sprite
			var sprite_rect = Rect2(block_rect)
			sprite_rect.position += Vector2.ONE * 4
			sprite_rect.size -= Vector2.ONE * 8
			
			var block = block_grid.blocks[i][j] as CoBlockGrid.BlockData
			match block.id:
				CoBlockGrid.BLOCK.AIR:
					node2d.draw_line(sprite_rect.position, sprite_rect.end, Color.AQUAMARINE, 3)
				CoBlockGrid.BLOCK.STONE:
					node2d.draw_rect(sprite_rect, Color.DIM_GRAY, true)
					node2d.draw_rect(sprite_rect, Color.BLACK, false)
				CoBlockGrid.BLOCK.TNT:
					node2d.draw_rect(sprite_rect, Color.DARK_RED, true)
					var tnt_stripe_rect = Rect2(sprite_rect)
					tnt_stripe_rect.position.y += tnt_stripe_rect.size.y / 3
					tnt_stripe_rect.size.y /= 3
					node2d.draw_rect(tnt_stripe_rect, Color.WHITE, true)
					node2d.draw_rect(sprite_rect, Color.BLACK, false)
					pass
			
			# on fire
			if block.on_fire:
				var fire_rect = Rect2(sprite_rect)
				fire_rect.position.x += fire_rect.size.x * 0.7
				fire_rect.size *= 1.0 - 0.7
				node2d.draw_rect(fire_rect, Color.ORANGE, true)


func on_process_entity(entity: Entity, _data, delta: float):
	if (self as Node) is Node2D:
		(self as Node as Node2D).queue_redraw()


func is_client() -> bool:
	var single_client = ECS.get_singleton_component(self, CoClient.label) as CoClient
	return single_client != null
