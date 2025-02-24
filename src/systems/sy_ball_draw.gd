class_name SyBallAim
extends System
const label: StringName = StringName("SyBallAim")


func _ready():
	components = [CoActor.label, CoCollider.label, CoBall.label]
	super()

	
func on_process_entity(entity: Entity, _data, _delta: float):
	var co_actor_renderer = entity.get_component(CoActorRenderer.label) as CoActorRenderer
	var co_ball = entity.get_component(CoBall.label) as CoBall
	
	if (co_actor_renderer is Node2D):
		var node_2d = co_actor_renderer as Node2D
		node_2d.rotation = co_ball.aim_radians
		#node_2d.rotation = lerp_angle(node_2d.rotation, co_ball.aim_radians, 1.5 * delta)
		
