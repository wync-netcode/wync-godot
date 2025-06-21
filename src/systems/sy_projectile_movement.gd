extends System
class_name SyProjectileMovement
const label: StringName = StringName("SyProjectileMovement")


func _ready():
	components = [CoVelocity.label, CoArea.label, CoProjectileData.label]
	super()

	
func on_process_entity(entity: Entity, _data, delta: float):
	var entity_node = entity as Node as Node2D
	var velocity = entity.get_component(CoVelocity.label) as CoVelocity
	var area_node: Area2D = entity.get_component(CoArea.label) as Area2D
	var pro_data = entity.get_component(CoProjectileData.label) as CoProjectileData

	var explode = false
	if area_node.has_overlapping_bodies():
		var bodies = area_node.get_overlapping_bodies()
		for body in bodies:

			# collided with an actor
			if body is Component:
				var actor: CoActor = get_actor_from_component(body)
				if actor:
					print("D: actor.id %s == %s ?" % [actor.id, pro_data.owner_actor_id])

					if actor.id == pro_data.owner_actor_id:
						continue
					else:
						explode = true

			# collided with solid
			else:
				explode = true
				print("D: Collided iwht solid")

	# dead by timer
	if pro_data.ticks_alive >= floori(Engine.physics_ticks_per_second * 1):
		explode = true
		pass
	pro_data.ticks_alive += 1

	# explode
	if explode:
		pro_data.alive = false
		var co_actor = entity.get_component(CoActor.label) as CoActor
		var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
		var ctx = single_wync.ctx as WyncCtx

		print("D: Projectile Exploded actor_id(%s)" % [co_actor.id])

		# unregister
		SyActorRegister.remove_actor(self, co_actor.id)

		# remove from Wync
		WyncTrack.untrack_entity(ctx, co_actor.id)

		# remove from ECS
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
