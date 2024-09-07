extends System
class_name SyActorMovement

func _ready():
	components = "CoActor,CoVelocity,CoCollider,CoActorInput"
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var node2d = entity as Node as Node2D
	var input = entity.get_component("coactorinput") as CoActorInput
	var velocity = entity.get_component("covelocity") as CoVelocity

	# apply friction
	var friction: float = StaticData.singleton.Player.friction * _delta
	if velocity.velocity.length() < friction:
		velocity.velocity = Vector2.ZERO
	else:
		velocity.velocity -= velocity.velocity.normalized() * friction

	# apply inputs to velocity
	velocity.velocity += input.movement_dir * StaticData.singleton.Player.acc * _delta

	# cap
	var cap = StaticData.singleton.Player.max_speed
	if velocity.velocity.length() > cap:
		velocity.velocity = velocity.velocity.normalized() * cap

	# integrate velocity to position
	node2d.position += velocity.velocity
	
	print("velocity ", velocity.velocity.length())
