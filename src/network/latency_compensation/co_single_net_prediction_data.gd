extends Component
class_name CoSingleNetPredictionData
static var label = ECS.add_component()
# TODO: Pick a better class name

# periodical vars

## to get target_time add this to curr_time -> curr_time + tick_offset * fixed_step
var tick_offset: int = 0
var tick_offset_prev: int = 0
var tick_offset_desired: int = 0
var target_tick: int = 0 # co_ticks.ticks + tick_offset
## fixed timestamp for current tick
## It's the point of reference for other ticks
var current_tick_timestamp: int = 0

# For calculating clock_offset_mean

var clock_packets_received: int
var clock_offset_mean: float
var clock_offset_accumulator: int

# To stabilize the latency
# TODO: Determine if this should be here, i.e. if this is related to prediction

var latency_stable: int
var latency_mean: int
var latency_std_dev: int
const LATENCY_BUFFER_SIZE: int = 20 ## 20 size, 2 polls per second -> 10 seconds worth
var latency_buffer: Array[int]
var latency_buffer_head: int = 0


func _ready() -> void:
	latency_buffer.resize(LATENCY_BUFFER_SIZE)
