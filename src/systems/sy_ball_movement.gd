class_name SyBallMovement
extends System
const label: StringName = StringName("SyBallMovement")


func _ready():
	components = [CoActor.label, CoCollider.label, CoBall.label]
	super()

	
func on_process_entity(entity: Entity, _data, delta: float):
	simulate_movement(entity, delta)
	recalculate_aim(entity)


static func simulate_movement(entity: Entity, _delta: float) -> void:
	
	var co_ball = entity.get_component(CoBall.label) as CoBall
	var collider = entity.get_component(CoCollider.label) as CoCollider
	var body = collider as Node as CharacterBody2D

	if body.velocity.length_squared() == 0:
		body.velocity = Vector2(1, 1) *  co_ball.SPEED
		
	var kin_col = body.move_and_collide(body.velocity)
	if kin_col:
		var col_normal = kin_col.get_normal()
		if col_normal.x != 0:
			body.velocity.x *= -1
		if col_normal.y != 0:
			body.velocity.y *= -1


func recalculate_aim(entity: Entity):
	var game_ticks = Engine.get_physics_frames()
	var physics_fps = Engine.physics_ticks_per_second
	
	if (game_ticks % (physics_fps * 2) == 0):
		var co_ball = entity.get_component(CoBall.label) as CoBall
		co_ball.aim_radians = randf() * 2 * PI
