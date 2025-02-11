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
# Ring <NetTickData>
# NOTE: For the client this might be NetTickData, for the server it isn't
var confirmed_states: RingBuffer = RingBuffer.new(10)

var pred_curr: NetTickData = NetTickData.new()
var pred_prev: NetTickData = NetTickData.new()

# DEPRECATED: Now global events aren't tied to a regular entity
# but insted they're tied to the singleton Client entity that is 
# assigned to each Peer
# global events
#var push_to_global_event: bool = false
#var global_event_channel: int = 0
