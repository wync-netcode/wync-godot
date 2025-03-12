extends Node2D


var gs := Plat.GameState.new()


func _ready() -> void:
	PlatGlobals.initialize()
	PlatNet.initialize_net_state(gs, true)
	PlatNet.register_peer_myself(gs)

	gs.wctx = WyncCtx.new()
	PlatWync.setup_client(gs.wctx)

	# loopback.register_peer()
	PlatPrivate.initialize_game_state(gs)
	#PlatPrivate.generate_world(gs)
	#PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10))
	#PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(7, 10))


func _physics_process(delta: float) -> void:
	if gs.net.client.state == Plat.Client.STATE.DISCONNECTED:
		# TODO: throttle
		PlatNet.client_send_connection_request(gs)
	PlatNet.consume_loopback_packets(gs)
	PlatWync.client_spawn_actors(gs, gs.wctx)

	#PlatPublic.player_input_additive(gs, gs.players[0], self)
	#PlatPublic.system_ball_movement(gs, self)
	#PlatPublic.system_player_movement(gs, delta)
	#PlatPublic.player_input_reset(gs, gs.players[0], self)


	
	WyncFlow.wync_client_set_current_latency(gs.wctx, PlatGlobals.loopback_ctx.latency)
	WyncFlow.wync_client_tick_end(gs.wctx)
	WyncThrottle.wync_set_data_limit_chars_for_out_packets(gs.wctx, 50000)
	WyncThrottle.wync_system_gather_packets(gs.wctx)
	PlatNet.queue_wync_packets(gs)

	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
