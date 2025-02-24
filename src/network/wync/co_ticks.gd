class_name CoTicks

@export var ticks_initial_value: int
@export var time_ms_offset: int

var ticks: int
var server_ticks: int

var server_ticks_offset_initialized: bool = false
var server_ticks_offset: int

# TODO: Move this elsewhere
# used to (1) lerp and (2) time warp
var lerp_delta_accumulator_ms: int
var last_tick_rendered_left: int


func _ready() -> void:
	ticks = ticks_initial_value
