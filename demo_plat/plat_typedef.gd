class_name Plat


const ACTOR_AMOUNT := 20
const BALL_AMOUNT := 4
const PLAYER_AMOUNT := 4
const CHUNK_AMOUNT := 5
const ROCKET_AMOUNT := 30

const CHUNK_WIDTH_BLOCKS := 5
const CHUNK_HEIGHT_BLOCKS := 10
const BLOCK_LENGTH_PIXELS := 24
const BALL_GRAVITY := 1
const BALL_MAX_SPEED := 3
const PLAYER_ACC := 30
const PLAYER_FRICTION := 4
const PLAYER_MAX_SPEED := 3.5
const PLAYER_GRAVITY := 5
const PLAYER_JUMP_SPEED := 2.7
const ROCKET_SPEED := 4.5
const ROCKET_TIME_TO_LIVE_MS := 3200


enum {
	LERP_TYPE_FLOAT,
	LERP_TYPE_VECTOR2,
	LERP_TYPE_VECTOR3,
	LERP_TYPE_QUATERNION
}


enum {
	ACTOR_TYPE_BALL,
	ACTOR_TYPE_PLAYER,
	ACTOR_TYPE_CHUNK,
	ACTOR_TYPE_ROCKET,
	ACTOR_TYPE_AMOUNT,
}


enum {
	BLOCK_TYPE_AIR,
	BLOCK_TYPE_DIRT,
	BLOCK_TYPE_IRON,
	BLOCK_TYPE_GOLD,
	BLOCK_TYPE_AMOUNT,
}


class Block:
	var type: int


class PlayerInput:
	var movement_dir: Vector2
	var aim: Vector2
	var shoot: bool

	func copy() -> PlayerInput:
		var i = PlayerInput.new()
		i.movement_dir = movement_dir
		i.aim = aim
		i.shoot = shoot
		return i


class Trail:
	var position: Vector2
	var hue: float # [0.0 - 1.0]
	var tick_duration: int


class Actor:
	#var actor_id: int # global actor identifier
	var actor_type: int # type of actor (e.g. Ball, Player, Chunk, etc)
	var instance_id: int # identifier between instances of it's type (e.g. gs.balls[id])


class Player:
	var actor_id: int
	var size: Vector2
	var position: Vector2
	var velocity: Vector2
	var input: PlayerInput


class Chunk:
	var actor_id: int
	var blocks: Array[Array] #: Array[Array[Block]]


class Ball:
	var actor_id: int
	var size: Vector2
	var position: Vector2
	var velocity: Vector2


class Rocket:
	var actor_id: int
	var size: Vector2
	var position: Vector2
	var direction: Vector2
	var time_to_live_ms: int


class GameState:
	# game world
	var actors: Array[Actor]   # Array[Actor*]
	var chunks: Array[Chunk]   # Array[Chunk*]
	var balls: Array[Ball]     # Array[Ball*]
	var players: Array[Player] # Array[Player*]
	var rockets: Array[Rocket] # Array[Rocket*]
	var trails: Array[Trail]   # List[Trail]
	var actors_added_or_deleted: bool
	var i_control_player_id: int # players actor id
	var camera_offset: Vector2

	# misc
	var net: NetState
	var wctx: WyncCtx
	#var wync_tracked_actors: Array[] # TODO


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
