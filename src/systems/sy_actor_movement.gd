class_name SyActorMovement
extends System
const label: StringName = StringName("SyActorMovement")


func _ready():
	components = [CoActor.label, CoCollider.label, CoActorInput.label]
	super()

	
func on_process_entity(entity: Entity, _data, delta: float):
	simulate_particle_on_start_moving(entity, delta, 0)
	simulate_movement(entity, delta)


# do not modify input, it is read only. I'm debugging if the inputs are equal
static func simulate_movement(entity: Entity, delta: float) -> void:
	
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	var collider = entity.get_component(CoCollider.label) as CoCollider
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


static func simulate_particle_on_start_moving(entity: Entity, _delta: float, predicted_tick: int) -> void:
	var single_wync = ECS.get_singleton_component(entity, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	var collider = entity.get_component(CoCollider.label) as CoCollider
	var body = collider as Node as CharacterBody2D
	
	if input.movement_dir_prev == Vector2.ZERO && input.movement_dir != Vector2.ZERO:
		
		# Demonstrates how to execute a visual effect only once even though we're
		# resimulating this tick multiple times for extrapolation/self-prediction
		if WyncUtils.is_client(wync_ctx, wync_ctx.my_peer_id):
			var action_id = "visual_effects"
			if WyncEventUtils.action_already_ran_on_tick(wync_ctx, predicted_tick, action_id):
				return
			WyncEventUtils.action_mark_as_ran_on_tick(wync_ctx, predicted_tick, action_id)
		
		var is_client = WyncUtils.is_client(wync_ctx)
		var particle_color = Color.RED if is_client else Color.BLUE
		DebugParticle.spawn(entity.get_tree().root, body.global_position, particle_color)
