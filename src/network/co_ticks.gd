extends Component
class_name CoTicks
static var label = ECS.add_component()

@export var ticks_initial_value: int
@export var time_ms_offset: int

var ticks: int
var server_ticks: int

var server_ticks_offset_initialized: bool = false
var server_ticks_offset: int


func _ready() -> void:
	ticks = ticks_initial_value
