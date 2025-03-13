extends Node2D


var gs := Plat.GameState.new()


func _ready() -> void:
	PlatGlobals.initialize()
	PlatNet.initialize_net_state(gs, false)
	PlatNet.register_peer_myself(gs)

	gs.wctx = WyncCtx.new()
	PlatWync.setup_server(gs.wctx)

	PlatPrivate.initialize_game_state(gs)
	PlatPrivate.generate_world(gs)
	PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10))
	#PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(7, 10))


func _physics_process(delta: float) -> void:
	PlatNet.consume_loopback_packets(gs)
	WyncFlow.wync_server_tick_start(gs.wctx)

	PlatWync.setup_connect_client(gs)

	#PlatPublic.player_input_additive(gs, gs.players[0], self)
	PlatPublic.system_ball_movement(gs, self)
	PlatPublic.system_player_movement(gs, delta, [])
	#PlatPublic.player_input_reset(gs, gs.players[0], self)

	PlatWync.update_what_the_clients_can_see(gs)

	WyncFlow.wync_client_set_current_latency(gs.wctx, PlatGlobals.loopback_ctx.latency)
	WyncFlow.wync_server_tick_end(gs.wctx)
	WyncThrottle.wync_set_data_limit_chars_for_out_packets(gs.wctx, 10000)
	WyncThrottle.wync_system_gather_packets(gs.wctx)
	PlatNet.queue_wync_packets(gs)

	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
