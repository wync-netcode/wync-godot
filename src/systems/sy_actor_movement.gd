extends System
class_name SyActorMovement

func _ready():
	components = "CoActor,CoVelocity,CoCollider,CoActorInput"
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var node2d = entity as Node as Node2D
	var input = entity.get_component("coactorinput") as CoActorInput
	var velocity = entity.get_component("covelocity") as CoVelocity
	var collider = entity.get_component("cocollider") as CoCollider
	var body = collider as CharacterBody2D

	# apply friction
	#print(entity.name, input.movement_dir)
	if input.movement_dir.length() == 0:
		var friction: float = StaticData.entity.Player.friction * _delta
		if velocity.velocity.length() < friction:
			velocity.velocity = Vector2.ZERO
		else:
			velocity.velocity -= velocity.velocity.normalized() * friction

	# apply inputs to velocity
	velocity.velocity += input.movement_dir * StaticData.entity.Player.acc * _delta

	# cap
	var cap = StaticData.entity.Player.max_speed
	if velocity.velocity.length() > cap:
		velocity.velocity = velocity.velocity.normalized() * cap

	# integrate velocity to position
	body.velocity = velocity.velocity
	body.move_and_slide()
	node2d.global_position = body.global_position
	body.position = Vector2.ZERO
	velocity.velocity = body.velocity
