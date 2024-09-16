extends System
class_name SyProjectileMovement


func _ready():
	components = "%s,%s,%s" % [CoVelocity.label, CoArea.label, CoProjectileData.label]
	super()

	
func on_process_entity(entity: Entity, delta: float):
	var entity_node = entity as Node as Node2D
	var velocity = entity.get_component(CoVelocity.label) as CoVelocity
	var area_node: Area2D = entity.get_component(CoArea.label) as Area2D
	var pro_data = entity.get_component(CoProjectileData.label) as CoProjectileData

	if area_node.has_overlapping_bodies():
		var explode = false
		var bodies = area_node.get_overlapping_bodies()
		for body in bodies:

			# collided with an actor

			if body is Component:
				var actor: CoActor = get_actor_from_component(body)
				if actor:
					print("actor.id %s == %s ?" % [actor.id, pro_data.owner_actor_id])

					if actor.id == pro_data.owner_actor_id:
						continue
					else:
						explode = true

			# collided with solid

			else:
				explode = true
				print("collided iwht solid")

		# explode

		if explode:
			print("Projectile Exploded")
			ECS.remove_entity(entity)
			return

	entity_node.position += velocity.velocity * delta


func get_actor_from_component(component: Component) -> CoActor:
	if not component:
		return null
	var entity: Entity = ECSUtils.get_entity_from_component(component)
	if not entity:
		return null
	if not entity.has_component(CoActor.label):
		return null
	return entity.get_component(CoActor.label) as CoActor
