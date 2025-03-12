class_name PlatWync


static func setup_server(ctx: WyncCtx):
	WyncUtils.server_setup(ctx)
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)


static func setup_client(ctx: WyncCtx):
	ctx.co_ticks.ticks = 200
	WyncUtils.client_init(ctx)
	
	WyncFlow.wync_client_set_physics_ticks_per_second(ctx, Engine.physics_ticks_per_second)
	WyncUtils.clock_set_debug_time_offset(ctx, 1000)

	# set server tick rate and lerp_ms
	var server_tick_rate: int = ctx.physic_ticks_per_second
	#var desired_lerp: int = ceil((1000.0 / server_tick_rate) * 6) # 6 ticks in the past
	WyncFlow.wync_client_set_lerp_ms(ctx, server_tick_rate, 200)
