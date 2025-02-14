class_name PhysicsUtils

const DYNAMIC_LAYER_START = 11
const DYNAMIC_LAYER_END = 15
const LAYER_INCREMENT = 5


static func initialize_collider(co_collider: CoCollider) -> void:
	var co_single_world = ECS.get_singleton_component(co_collider, CoSingleWorld.label) as CoSingleWorld
	if not co_single_world:
		print("E: Couldn't find singleton CoSingleWorld for %s" % co_collider)
		return
	var world_id = co_single_world.world_id

	var body = co_collider as Node as CollisionObject2D
	if not body:
		print("E: Collider is not CharacterBody %s" % co_collider)
		return

	# increment collisions layers/masks by world id

	for i in range(DYNAMIC_LAYER_START, DYNAMIC_LAYER_END +1):
		if body.get_collision_layer_value(i):
			body.set_collision_layer_value(i, false)
			body.set_collision_layer_value(i + LAYER_INCREMENT * world_id, true)
		if body.get_collision_mask_value(i):
			body.set_collision_mask_value(i, false)
			body.set_collision_mask_value(i + LAYER_INCREMENT * world_id, true)
	
	co_collider.initialized = true


static func initialize_raycast_layers(co_raycast: CoRaycast) -> void:
	var co_single_world = ECS.get_singleton_component(co_raycast, CoSingleWorld.label) as CoSingleWorld
	if not co_single_world:
		print("E: Couldn't find singleton CoSingleWorld for %s" % co_raycast)
		return
	var world_id = co_single_world.world_id

	var ray_node = co_raycast as Node as RayCast2D
	if not ray_node:
		print("E: CoRaycast is not Raycast2D %s" % co_raycast)
		return

	# increment collisions layers/masks by world id

	for i in range(DYNAMIC_LAYER_START, DYNAMIC_LAYER_END +1):
		if ray_node.get_collision_mask_value(i):
			ray_node.set_collision_mask_value(i, false)
			ray_node.set_collision_mask_value(i + LAYER_INCREMENT * world_id, true)
	
	co_raycast.initialized = true
