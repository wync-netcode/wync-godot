class_name CoPredictionData

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
# TODO: Move this to co_ticks

var clock_offset_sliding_window: RingBuffer = null
var clock_offset_sliding_window_size: int = 16
var clock_offset_mean: float

# Interpolation data
# TODO: Move this elsewhere

var lerp_ms: int = 50


func _init() -> void:
	clock_offset_sliding_window = RingBuffer.new(clock_offset_sliding_window_size, 0)
