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
	Loopback.system_fluctuate_latency(loopback_ctx)

	if Input.is_action_just_pressed("key_debug_1"):
		if loopback_ctx.peers.size() > 1: loopback_ctx.peers[1].disabled = true
	if Input.is_action_just_released("key_debug_1"):
		if loopback_ctx.peers.size() > 1: loopback_ctx.peers[1].disabled = false


## This would emulate the net stack working in the background

func _process(_delta: float) -> void:
	Loopback.system_service(loopback_ctx)
