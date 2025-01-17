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
}

var name_id: String
var data_type: DATA_TYPE
var getter: Callable
var setter: Callable

# Optional properties:
# TODO: Move these elsewhere

var dirty: bool # new state was received from the server
#var predicted: bool # aka extrapolation / self-prediction
var interpolated: bool

# Ring <NetTickData>
var confirmed_states: RingBuffer = RingBuffer.new(10)

var pred_curr: NetTickData = NetTickData.new()
var pred_prev: NetTickData = NetTickData.new()
