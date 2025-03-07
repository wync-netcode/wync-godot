extends Component
class_name CoTransportLoopback
static var label = ECS.add_component()

var ctx: Loopback.Context


func _ready():
	ctx = Loopback.Context.new()


func _physics_process(_delta: float) -> void:
	Loopback.system_fluctuate_latency(ctx)
