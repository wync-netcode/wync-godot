class_name Plat


const LOGIC_DELTA_MS: float = 1.0/60
const ACTOR_AMOUNT := 20
const BALL_AMOUNT := 4
const PLAYER_AMOUNT := 4
const CHUNK_AMOUNT := 6
const ROCKET_AMOUNT := 30

const CHUNK_WIDTH_BLOCKS := 6
const CHUNK_HEIGHT_BLOCKS := 10
const BLOCK_LENGTH_PIXELS := 24
const BALL_GRAVITY := 1
static var BALL_MAX_SPEED := 240.0 / Engine.physics_ticks_per_second
const PLAYER_ACC := 30
const PLAYER_FRICTION := 4
const PLAYER_MAX_SPEED := 3.5
const PLAYER_GRAVITY := 5
const PLAYER_JUMP_SPEED := 2.7
const ROCKET_SPEED := 4.5
const ROCKET_TIME_TO_LIVE_MS := 3200

static var CHUNK_ACTOR_ID_RANGE_START: int = 500
static var CHUNK_ACTOR_ID_RANGE_END: int = CHUNK_ACTOR_ID_RANGE_START + CHUNK_AMOUNT

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


class PlayerInput:
	var movement_dir: Vector2
	var aim: Vector2
	var shoot: bool
	var shoot_secondary: bool

	func copy() -> PlayerInput:
		var i = PlayerInput.new()
		i.movement_dir = movement_dir
		i.aim = aim
		i.shoot = shoot
		i.shoot_secondary = shoot_secondary
		return i

	func copyTo(i: PlayerInput):
		i.movement_dir = movement_dir
		i.aim = aim
		i.shoot = shoot
		i.shoot_secondary = shoot_secondary


class Trail:
	var position: Vector2
	var hue: float # [0.0 - 1.0]
	var tick_duration: int


class RayTrail:
	var from: Vector2
	var to: Vector2
	var hue: float # [0.0 - 1.0]
	var tick_duration: int


class Block:
	var type: int


class Chunk:
	var actor_id: int
	var position: int # where in the world is located
	var blocks: Array[Array] #: Array[Array[Block]]


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
	var visual_position: Vector2


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
	var actor_ids: Dictionary[int, int] # Map<actor_id: int, actor_index: int>

	var chunks: Array[Chunk]   # Array[Chunk*]
	var balls: Array[Ball]     # Array[Ball*]
	var players: Array[Player] # Array[Player*]
	var rockets: Array[Rocket] # Array[Rocket*]
	var box_trails: Array[Trail]   # List[Trail]
	var ray_trails: Array[RayTrail]   # List[Trail]
	var actors_added_or_deleted: bool
	var i_control_player_id: int # players actor id
	var camera_offset: Vector2

	# misc
	var net: NetState
	var wctx: WyncCtx
	#var wync_tracked_actors: Array[] # TODO


# Networking data
# --------------------------------------------------


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


class RocketSpawnData: # This represents the position
	var tick: int
	var value1: Vector2
	var value2: Vector2

	func duplicate() -> RocketSpawnData:
		var i = RocketSpawnData.new()
		i.tick = tick
		i.value1 = value1
		i.value2 = value2
		return i


# Events
# --------------------------------------------------

enum {
	EVENT_NONE,

	# delta
	EVENT_DELTA_BLOCK_REPLACE,

	# player input
	EVENT_PLAYER_SHOOT,
	EVENT_PLAYER_BLOCK_BREAK,
	EVENT_PLAYER_BLOCK_PLACE,
}

# later filled on blueprint setup
static var BLUEPRINT_ID_BLOCK_GRID_DELTA = -1

class EventPlayerBlockBreak:
	var pos: Vector2i

	func duplicate() -> EventPlayerBlockBreak:
		var newi = EventPlayerBlockBreak.new()
		newi.pos = pos
		return newi

class EventDeltaBlockReplace:
	var pos: Vector2i
	var block_type: int

	func duplicate() -> EventDeltaBlockReplace:
		var newi = EventDeltaBlockReplace.new()
		newi.pos = pos
		newi.block_type = block_type
		return newi
