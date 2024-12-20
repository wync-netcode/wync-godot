class_name WyncEntityProp

enum DATA_TYPE {
	INT,
	FLOAT,
	VECTOR2
}

var name_id: String
var data_type: DATA_TYPE
var getter: Callable
var setter: Callable

# Optional properties:
# TODO: Move these elsewhere

# Ring<int | float | Vector2>
# Ring <NetTickData>
var confirmed_states: RingBuffer = RingBuffer.new(10)

var pred_curr: NetTickData = NetTickData.new()
var pred_prev: NetTickData = NetTickData.new()
