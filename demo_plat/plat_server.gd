extends Node2D


var gs := Plat.GameState.new()


func _ready() -> void:
	PlatPrivate.initialize_game_state(gs)
	PlatPrivate.generate_world(gs)
	PlatPublic.spawn_ball(gs, PlatUtils.GRID_CORD(5, 10))


func _physics_process(delta: float) -> void:
	PlatPublic.system_ball_movement(gs, self)
	queue_redraw()


func _draw():
	PlatDraw.draw_game(self, gs)
