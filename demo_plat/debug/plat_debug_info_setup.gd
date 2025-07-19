extends Node


@onready var server = %"Server"
@onready var client = %"Client"
var show_debug_info: bool = true


func _ready():
	PlatGlobals.initialize()
	recursively_initialize_debug_info(self)


func recursively_initialize_debug_info(node: Node):
	for child in node.get_children():
		if child is DynamicDebugInfo:
			child.initialize(PlatGlobals.loopback_ctx, server.gs.wctx, client.gs.wctx)
		else:
			recursively_initialize_debug_info(child)


func recursively_change_visibility(node: Node):
	for child in node.get_children():
		if child is DynamicDebugInfo:
			child.visible = show_debug_info
		else:
			recursively_change_visibility(child)


func _physics_process(_delta: float) -> void:
	if Input.is_action_just_pressed("key_debug_3"):
		show_debug_info = not show_debug_info
		recursively_change_visibility(self)
