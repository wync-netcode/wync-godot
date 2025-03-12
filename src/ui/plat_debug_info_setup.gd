extends Node


@onready var server = %"Server"
@onready var client = %"Client"


func _ready():
	PlatGlobals.initialize()
	recursively_initialize_debug_info(self)


func recursively_initialize_debug_info(node: Node):
	for child in node.get_children():
		if child is DynamicDebugInfo:
			child.initialize(PlatGlobals.loopback_ctx, server.gs.wctx, client.gs.wctx)
		else:
			recursively_initialize_debug_info(child)
