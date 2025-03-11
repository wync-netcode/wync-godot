extends Component
class_name CoBlockGrid
static var label = ECS.add_component()

enum BLOCK {
	AIR,
	DIRT,
	STONE,
	GOLD,
	DIAMOND
}

class BlockData:
	var id: BLOCK = BLOCK.AIR
	var on_fire: bool = false

const LENGTH = 4 # 16 tiles
var blocks: Array[Array] # Array[Array[BlockData]]

class BlockGridPortable:
	var blocks: Array[Array]

	func _init() -> void:
		blocks = []
		blocks.resize(LENGTH)
		for i in range(LENGTH):
			blocks[i] = []
			blocks[i].resize(LENGTH)
			for j in range(LENGTH):
				blocks[i][j] = BlockData.new()

	func duplicate() -> BlockGridPortable:
		var instance = BlockGridPortable.new()
		for i in range(LENGTH):
			for j in range(LENGTH):
				instance.blocks[i][j].id = self.blocks[i][j].id
				instance.blocks[i][j].on_fire = self.blocks[i][j].on_fire
		return instance


func make_duplicate() -> BlockGridPortable:
	var instance = BlockGridPortable.new()
	for i in range(LENGTH):
		for j in range(LENGTH):
			instance.blocks[i][j].id = self.blocks[i][j].id
			instance.blocks[i][j].on_fire = self.blocks[i][j].on_fire
	return instance


func _init() -> void:
	# initialize two dimensional array
	blocks = []
	blocks.resize(LENGTH)
	for i in range(LENGTH):
		blocks[i] = []
		blocks[i].resize(LENGTH)
		for j in range(LENGTH):
			blocks[i][j] = BlockData.new()

func generate_random_blocks():
	
	# random blocks
	var random_generator = RandomNumberGenerator.new()
	for i in range(LENGTH):
		for j in range(LENGTH):
			# block id
			# 0: air
			# 1: stone
			# 2: tnt
			blocks[i][j].id = random_generator.randi_range(BLOCK.AIR, BLOCK.DIAMOND)
			
			# on fire
			if random_generator.randi_range(0, 3) == 0:
				blocks[i][j].on_fire = true


func set_from_instance(block_grid: CoBlockGrid.BlockGridPortable):
	for i in range(LENGTH):
		for j in range(LENGTH):
			self.blocks[i][j].id = block_grid.blocks[i][j].id
			self.blocks[i][j].on_fire = block_grid.blocks[i][j].on_fire
