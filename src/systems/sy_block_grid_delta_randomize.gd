extends System
class_name SyBlockGridDeltaRandomize
const label: StringName = StringName("SyBlockGridDeltaRandomize")


func on_process(_entities, _data, _delta):
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	if co_ticks.ticks % Engine.physics_ticks_per_second != 0:
		return
	
	var en_block_grid = ECS.get_singleton_entity(self, "EnBlockGrid")
	if en_block_grid:
		insert_random_block(en_block_grid)
	else:
		Log.err(self, "coulnd't get singleton EnBlockGrid")

	en_block_grid = ECS.get_singleton_entity(self, "EnBlockGridDelta")
	if en_block_grid:
		insert_random_block(en_block_grid)
	else:
		Log.err(self, "coulnd't get singleton EnBlockGridDelta")

func insert_random_block(en_block_grid: Entity):
	
	var block_pos = Vector2i(randi_range(0, CoBlockGrid.LENGTH-1), randi_range(0, CoBlockGrid.LENGTH-1))
	var block_type = [CoBlockGrid.BLOCK.AIR, CoBlockGrid.BLOCK.STONE, CoBlockGrid.BLOCK.TNT].pick_random()
	var co_block_grid = en_block_grid.get_component(CoBlockGrid.label) as CoBlockGrid
	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData
	block_data.id = block_type

	# Commit a Delta Event here


### WOYNERT DUMP: 
### * Stop extracting data for Delta Synced Props
### * New system that periodically updates the Delta Syncs Ticks / etc
### * New system that correctly extracts data from Delta Syncs? Maybe not needed because 
### 	All changes are reported? I mean, creation, modification (deltas), etc is all reported...
