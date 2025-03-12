extends Node
class_name PlatGlobals

static var singleton: PlatGlobals = null
var loop_ctx: Loopback.Context = null


func _ready():
	PlatGlobals.singleton = self
	loop_ctx = Loopback.Context.new()
