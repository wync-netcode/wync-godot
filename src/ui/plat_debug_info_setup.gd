extends Node


@onready var server = %"Server"
@onready var client = %"Client"


func _ready():
	PlatGlobals.initialize()
	for child in get_children():
		child.initialize(PlatGlobals.loopback_ctx, server.gs.wctx, client.gs.wctx)
