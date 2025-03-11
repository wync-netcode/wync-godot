extends Component
class_name CoTransportLoopback
static var label = ECS.add_component()

var ctx: Loopback.Context


func _ready():
	ctx = Loopback.Context.new()


func _physics_process(_delta: float) -> void:
	if Engine.get_physics_frames() % Engine.physics_ticks_per_second == 0:
		Loopback.system_fluctuate_latency(ctx)
