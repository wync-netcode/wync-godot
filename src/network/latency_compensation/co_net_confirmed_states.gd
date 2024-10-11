extends Component
class_name CoNetConfirmedStates
static var label = ECS.add_component()

var buffer: RingBuffer = RingBuffer.new(4) #:RingBuffer[NetTickData]


"""

const BUFFER_SIZE: int = 4
# Array[tick (int), data (Any)]
var buffer: Array[TickData]
var buffer_head: int = 0


func _init() -> void:
	buffer.resize(BUFFER_SIZE)


# NOTE: buffer_head could be inconsistent if ticks are inserted out of order
func add_tick(tick: int, data: TickData) -> void:
	buffer_head = tick % BUFFER_SIZE
	buffer[buffer_head] = data


func get_tick(tick: int) -> TickData:
	var data = buffer[tick % BUFFER_SIZE]
	if data != null && data.tick == tick:
		return data
	return null
"""
