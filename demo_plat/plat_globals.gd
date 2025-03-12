extends Node
class_name PlatGlobals

static var initialized: bool = false
static var loopback_ctx: Loopback.Context = null


static func initialize():
	if initialized:
		return
	initialized = true

	loopback_ctx = Loopback.Context.new()


var debug_reference
func _ready() -> void:
	initialize()
	debug_reference = loopback_ctx


## Run global processes

func _physics_process(_delta: float) -> void:
	Loopback.system_send_receive(loopback_ctx)
