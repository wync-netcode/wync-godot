class_name CoTicks

# for "debug_tick_offset" just set ctx.co_ticks.ticks to any value
var debug_time_offset_ms: int

var ticks: int
var server_ticks: int

var server_ticks_offset_initialized: bool = false
var server_ticks_offset: int

# TODO: Move this elsewhere
# used to (1) lerp and (2) time warp
var lerp_delta_accumulator_ms: int
var last_tick_rendered_left: int
