class_name Plat

const CHUNK_WIDTH_BLOCKS := 5
const CHUNK_HEIGHT_BLOCKS := 10
const CHUNK_AMOUNT := 5
const BLOCK_LENGTH_PIXELS := 24
const BALL_GRAVITY := 1
const BALL_MAX_SPEED := 3
const PLAYER_ACC := 30
const PLAYER_FRICTION := 4
const PLAYER_MAX_SPEED := 3.5
const PLAYER_GRAVITY := 5
const PLAYER_JUMP_SPEED := 2.7


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


class Ball:
	var size: Vector2
	var position: Vector2
	var velocity: Vector2


class PlayerInput:
	var movement_dir: Vector2
	var aim: Vector2
	var shoot: bool


class Player:
	var size: Vector2
	var position: Vector2
	var velocity: Vector2
	var input: PlayerInput


class GameState:
	# game world
	var chunks: Array[Chunk]
	var balls: Array[Ball]
	var players: Array[Player]

	# misc
	var net: NetState
	var wctx: WyncCtx


class NetState:
	var io_peer: Loopback.IOPeer
	var is_client: bool
	var server: Server
	var client: Client


class Server:
	class Peer:
		var identifier: int
		var peer_id: int
	var peer_count: int
	var peers: Array[Server.Peer]


class Client:
	enum STATE {
		DISCONNECTED,
		CONNECTED
	}
	var state: Client.STATE = Client.STATE.DISCONNECTED
	var identifier: int = -1
	var server_peer: int = -1  # key to actual peer, represents the connection stub
