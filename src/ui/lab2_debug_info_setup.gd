extends Node


@onready var co_loopback: CoTransportLoopback = %CoTransportLoopback
@onready var co_server_wctx: CoSingleWyncContext = %"CoSingleWyncContext-Server"
@onready var co_client_wctx: CoSingleWyncContext = %"CoSingleWyncContext-Client"


func _ready():
	for child in get_children():
		child.initialize(co_loopback.ctx, co_server_wctx.ctx, co_client_wctx.ctx)
