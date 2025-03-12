extends Node2D


var gs := Plat.GameState.new()


func _ready() -> void:
	PlatPrivate.initialize_game_state(gs)
	PlatPrivate.generate_world(gs)
	PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10))
	PlatPublic.spawn_player(gs, PlatUtils.GRID_CORD(7, 10))


func _physics_process(delta: float) -> void:
	PlatPublic.player_input_additive(gs, gs.players[0], self)
	PlatPublic.system_ball_movement(gs, self)
	PlatPublic.system_player_movement(gs, delta)
	PlatPublic.player_input_reset(gs, gs.players[0], self)
	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
