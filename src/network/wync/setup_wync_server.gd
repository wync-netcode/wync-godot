extends Node

## Just setup thing on the server for the Wync Library

func _ready() -> void:
	var co_wync_ctx = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_wync_ctx.ctx
	WyncUtils.server_setup(wync_ctx)
