class_name Plat

const CHUNK_WIDTH_BLOCKS := 5
const CHUNK_HEIGHT_BLOCKS := 10
const CHUNK_AMOUNT := 5
const BLOCK_LENGTH_PIXELS := 16
const BALL_GRAVITY := 1
const BALL_MAX_SPEED := 3

enum {
	BLOCK_TYPE_AIR,
	BLOCK_TYPE_DIRT,
	BLOCK_TYPE_IRON,
	BLOCK_TYPE_GOLD,
	BLOCK_TYPE_AMOUNT,
}


class Block:
	var type: int


class Chunk:
	var blocks: Array[Array] #: Array[Array[Block]]


class GameState:
	var chunks: Array[Chunk]
	var balls: Array[Ball]


class Ball:
	var position: Vector2
	var size: Vector2
	var velocity: Vector2
