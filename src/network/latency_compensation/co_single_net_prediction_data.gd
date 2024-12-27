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

# Interpolation data
# TODO: Move this elsewhere

var lerp_ms: int = 50


# =====================================================
## relation between predicted ticks to local ticks
# TODO: BETTER NAMES OR BETTER STRUCTURE

# TODO: Replace with WyncCtx.INPUT_BUFFER_SIZE
const BUFFER_SIZE = 60 * 12  ## 1.2 seconds worth of inputs
var buffer_predicted_tick: Array[int]  ## Array[tick_predicted: int, tick_local: int]
var buffer_predicted_tick_prev: Array[int]  ## Array[tick_predicted: int, tick_local: int]
var buffer_head_predicted_tick: int = 0


func set_tick_predicted(pred_tick: int, local_tick: int) -> void:
	buffer_head_predicted_tick = pred_tick % BUFFER_SIZE
	buffer_predicted_tick[buffer_head_predicted_tick] = local_tick
	buffer_predicted_tick_prev[buffer_head_predicted_tick] = pred_tick


func get_tick_predicted(pred_tick: int):# -> Optional<int>:
	var key = pred_tick % BUFFER_SIZE
	var data = buffer_predicted_tick[key]
	if pred_tick == buffer_predicted_tick_prev[key]:
		return data
	return null


#func _ready() -> void:
func _init() -> void:
	latency_buffer.resize(LATENCY_BUFFER_SIZE)
	
	# TODO: get server tick rate from server
	var physics_fps = Engine.physics_ticks_per_second
	lerp_ms = max(lerp_ms, (1000 / physics_fps) * 2)

	buffer_predicted_tick.resize(BUFFER_SIZE)
	buffer_predicted_tick_prev.resize(BUFFER_SIZE)
