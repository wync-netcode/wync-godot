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

	PlatWync.setup_sync_for_all_chunks(gs)
	var ball_actor_id = PlatPublic.spawn_ball_server(gs, PlatUtils.GRID_CORD(5, 8), Plat.BALL_BEHAVIOUR_LINE)
	PlatWync.setup_sync_for_ball_actor(gs, ball_actor_id)
	#ball_actor_id = PlatPublic.spawn_ball_server(gs, PlatUtils.GRID_CORD(7, 7), Plat.BALL_BEHAVIOUR_SINE)
	#PlatWync.setup_sync_for_ball_actor(gs, ball_actor_id)


func _physics_process(_delta: float) -> void:
	PlatNet.consume_loopback_packets(gs)
	WyncFlow.wync_server_tick_start(gs.wctx)

	PlatWync.setup_connect_client(gs)

	#PlatPublic.player_input_additive(gs, gs.players[0], self)
	PlatPublic.system_trail_lives(gs)
	PlatPublic.system_ball_movement(gs, Plat.LOGIC_DELTA_MS)
	PlatPublic.system_player_movement(gs, Plat.LOGIC_DELTA_MS, false, [])
	PlatPublic.system_rocket_movement(gs, false)
	PlatPublic.system_rocket_time_to_live(gs, Plat.LOGIC_DELTA_MS)
	PlatPublic.system_player_shoot_rocket(gs)
	PlatPublic.system_server_events(gs)
	PlatPublic.system_players_shoot_bullet_timewarp_ping_based(gs)
	#PlatPublic.player_input_reset(gs, gs.players[0], self)

	PlatWync.update_what_the_clients_can_see(gs)

	for wync_peer_id: int in range(1, gs.wctx.common.peers.size()):
		var nete_peer_id = gs.wctx.common.peers[wync_peer_id]
		var io_peer := PlatGlobals.loopback_ctx.peers[nete_peer_id]
		WyncClock.wync_peer_set_current_latency(gs.wctx, wync_peer_id, io_peer.latency_current_ms)

	WyncFlow.wync_server_tick_end(gs.wctx)

	#if Engine.get_physics_frames() % 16 == 0:
	#if Engine.get_physics_frames() % 8 == 0:
	if Engine.get_physics_frames() % 4 == 0:
	#if Engine.get_physics_frames() % 2 == 0:
	#if true:
		WyncPacketUtil.wync_set_data_limit_chars_for_out_packets(gs.wctx, 10000)
		WyncFlow.wync_system_gather_packets(gs.wctx)

	PlatNet.queue_wync_packets(gs)
	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
