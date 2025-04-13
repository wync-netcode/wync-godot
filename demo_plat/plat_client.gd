extends Node2D


var gs := Plat.GameState.new()


func _ready() -> void:
	PlatGlobals.initialize()
	PlatPrivate.initialize_game_state(gs)
	#PlatPrivate.generate_world(gs)
	PlatNet.initialize_net_state(gs, true)
	PlatNet.register_peer_myself(gs)

	gs.wctx = WyncCtx.new()
	PlatWync.setup_client(gs.wctx)


func _physics_process(delta: float) -> void:
	PlatNet.consume_loopback_packets(gs)

	if gs.net.client.state == Plat.Client.STATE.DISCONNECTED:
		# TODO: throttle
		PlatNet.client_send_connection_request(gs)

	#elif gs.net.client.state == Plat.Client.STATE.CONNECTED:

	if not gs.wctx.connected:
		WyncThrottle.wync_system_gather_packets(gs.wctx)
	else:
		PlatWync.client_event_connected_to_server(gs)
		PlatWync.client_handle_spawn_events(gs)
		PlatWync.find_out_what_player_i_control(gs)

		if gs.i_control_player_id != -1:
			PlatPublic.player_input_additive(gs, gs.players[gs.i_control_player_id], self)
			PlatPublic.system_player_grid_events(gs, gs.players[gs.i_control_player_id])
		
		WyncFlow.wync_peer_set_current_latency(gs.wctx, WyncCtx.SERVER_PEER_ID, gs.net.io_peer.latency_current_ms)
		WyncFlow.wync_client_tick_end(gs.wctx)

		PlatWync.extrapolate(gs, delta)

		WyncThrottle.wync_set_data_limit_chars_for_out_packets(gs.wctx, 50000)
		WyncThrottle.wync_system_gather_packets(gs.wctx)
		PlatPublic.system_trail_lives(gs)

		if gs.i_control_player_id != -1:
			PlatPublic.player_input_reset(gs, gs.players[gs.i_control_player_id])


	if gs.net.client.state == Plat.Client.STATE.CONNECTED:
		PlatNet.queue_wync_packets(gs)

	PlatWync.debug_draw_confirmed_interpolated_states(gs)

func _process(delta: float) -> void:
	WyncWrapper.wync_interpolate_all(gs.wctx, delta)
	PlatWync.set_interpolated_state(gs)
	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
