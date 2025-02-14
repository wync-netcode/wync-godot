class_name WyncEntityProp
"""
enum SYNC_STRAT {
	LATEST_VALUE,
	INTERPOLATED,
	PREDICTED # aka extrapolation / self-prediction
}"""

enum DATA_TYPE {
	INT,
	FLOAT,
	VECTOR2,
	INPUT, # a.k.a. any
	ANY,
	EVENT
}

static var INTERPOLABLE_DATA_TYPES: Array[DATA_TYPE] = [
	DATA_TYPE.FLOAT,
	DATA_TYPE.VECTOR2,
]

var name_id: String
var data_type: DATA_TYPE
var getter: Callable
var setter: Callable

# Optional properties:
# TODO: Move these elsewhere

var dirty: bool # new state was received from the server
var interpolated: bool
var interpolated_state # : any

# (server-side) the server will keep a history of state
var timewarpable: bool

# TODO: Make this value configurable on WyncCtx
# Ring <tick: id, data: Variant>
var confirmed_states: RingBuffer = RingBuffer.new(10)

## Last-In-First-Out (LIFO)
## LIFO Queue <arrival_order: int, server_tick: int>
var last_ticks_received: RingBuffer = RingBuffer.new(10)

## this server tick was received at this tick (used for lerping)
## LIFO Queue <server_tick: int, local_tick: int>
var arrived_at_tick: RingBuffer = RingBuffer.new(10)

## store predicted state
var pred_curr: NetTickData = NetTickData.new()
var pred_prev: NetTickData = NetTickData.new()

# UNUSED
# Precalculate which ticks we're gonna be interpolating between
# int: keys to 'confirmed_state'
var lerp_use_confirmed_state: bool
var lerp_left_local_tick: int # used to calculate timing
var lerp_right_local_tick: int

# Q: Why store specific tick range instead of using current one
# A: To support varying update rates per prop
var lerp_left_confirmed_state_tick: int
var lerp_right_confirmed_state_tick: int

# DEPRECATED: Now global events aren't tied to a regular entity
# but insted they're tied to the singleton Client entity that is 
# assigned to each Peer
# global events
#var push_to_global_event: bool = false
#var global_event_channel: int = 0
