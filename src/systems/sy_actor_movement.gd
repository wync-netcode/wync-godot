class_name SyActorMovement
extends System
const label: StringName = StringName("SyActorMovement")


func _ready():
	components = [CoActor.label, CoCollider.label, CoActorInput.label]
	super()

	
func on_process_entity(entity: Entity, _data, delta: float):
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	var collider = entity.get_component(CoCollider.label) as CoCollider
	simulate_movement(input, collider, delta)


# do not modify input, it is read only. I'm debugging if the inputs are equal
static func simulate_movement(input: CoActorInput, collider: CoCollider, delta: float) -> void:
	var body = collider as Node as CharacterBody2D
	var velocity = body.velocity

	#body.velocity = input.movement_dir.normalized() * StaticData.entity.Player.max_speed
	#body.move_and_slide()
	#return
		
	# apply friction

	var friction: float = StaticData.entity.Player.friction * delta
	if body.velocity.length() < friction:
		body.velocity = Vector2.ZERO
	else:
		body.velocity -= body.velocity.normalized() * friction

	# apply input

	var increment = input.movement_dir.normalized() * StaticData.entity.Player.acc * delta
	var max_speed = StaticData.entity.Player.max_speed
	var curr_speed = body.velocity.length()
	var would_be_speed = (body.velocity + increment).length()

	# Two cases:
	# (1) reduce speed

	if would_be_speed < curr_speed:
		body.velocity += increment

	# (2) increase speed
	else:

		# allow to achieve maximum speed
		if curr_speed < max_speed && would_be_speed > max_speed:
			curr_speed = max_speed

		# allow to move from stall
		elif would_be_speed <= max_speed:
			curr_speed += increment.length()

		# merge directions
		var dir = (body.velocity + increment).normalized()
		body.velocity = dir * curr_speed

	# integrate
	body.move_and_slide()


	pass
	
