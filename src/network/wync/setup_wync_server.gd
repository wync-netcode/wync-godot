extends Node

## Just setup thing on the server for the Wync Library

func _ready() -> void:
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	
	#if co_ticks < 0
	
	var co_wync_ctx = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = co_wync_ctx.ctx
	
	var wync_client_id = WyncUtils.client_register(wync_ctx, 0)
	# --> continues in sy_wync_setup_sync_player
	
