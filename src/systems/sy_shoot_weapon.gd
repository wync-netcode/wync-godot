extends System
class_name SyShootWeapon

func _ready():
	components = "CoActor,CoWeaponInventory,CoWeaponHeld,CoActorInput,CoCollider"
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var node2d = entity as Node as Node2D
	var actor = entity.get_component(CoActor.label) as CoActor
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	var weapon = entity.get_component(CoWeaponHeld.label) as CoWeaponHeld
	var inventory = entity.get_component(CoWeaponInventory.label) as CoWeaponInventory
	var collider = entity.get_component(CoCollider.label) as CoCollider

	# shooting

	if not input.shoot:
		return

	# find WeaponStored

	var weapon_stored: CoWeaponStored = null
	for w: CoWeaponStored in inventory.inventory:
		#print("CoWeaponStored ", w)
		#print("w.weapon_id", w.weapon_id)
		
		if w.weapon_id == weapon.weapon_id:
			weapon_stored = w
			break

	#sdprint("weapon_stored", weapon_stored)
	if weapon_stored == null:
		return
	
	
	# delay / cooldown between shots
	
	var current_time = Time.get_ticks_msec()
	if current_time - weapon_stored.time_last_shot < StaticData.entity.Weapons[weapon_stored.weapon_id].shoot_delay:
		return
	weapon_stored.time_last_shot = Time.get_ticks_msec()

	# enough bullets

	var has_bullets = weapon_stored.bullets_magazine_left > 0
	var is_melee = weapon.weapon_id == StaticData.WEAPON.MELEE
	if not (has_bullets || is_melee):
		return
	if has_bullets:
		weapon_stored.bullets_magazine_left -= 1

	# perform raycast
	# + account for weapon reach

	var is_projectile: bool = StaticData.entity.Weapons[weapon.weapon_id].bullet_type == 1
	var pellets: int = StaticData.entity.Weapons[weapon.weapon_id].pellet_count
	var spread: int = StaticData.entity.Weapons[weapon.weapon_id].spread_deg
	var aim_angle: float = node2d.global_position.angle_to_point(input.aim)
	var reach: int = 0
	var raycast: RayCast2D = null

	if not is_projectile:
		var raycast_ent = ECS.get_singleton_entity(self, "EnRaycastSingleton")
		if not raycast_ent:
			print("E: Couldn't find singleton EnRaycastSingleton")
			return
		var raycast_co = raycast_ent.get_component("coraycast") as CoRaycast
		raycast = raycast_co as Node as RayCast2D
		reach = raycast_co.default_reach

		if StaticData.entity.Weapons[weapon_stored.weapon_id].reach != 0:
			reach = StaticData.entity.Weapons[weapon_stored.weapon_id].reach

		raycast.clear_exceptions()
		raycast.add_exception(collider as CharacterBody2D)
		raycast.global_position = node2d.global_position

	# fire one of the pellets with perfect accuracy

	print("is_projectile %s %s" % [is_projectile, weapon.weapon_id])
	if pellets > 1:
		pellets -= 1
		if not is_projectile:
			bullet_raycast(weapon.weapon_id, raycast, aim_angle, reach)
		else:
			launch_projectile(weapon.weapon_id, actor.id, collider, aim_angle)

	# fire remaining

	for i in range(pellets):
		var angle = aim_angle + deg_to_rad(spread) * randf_range(-1, 1)
		if not is_projectile:
			bullet_raycast(weapon.weapon_id, raycast, angle, reach)
		else:
			launch_projectile(weapon.weapon_id, actor.id, collider, angle)


func launch_projectile(weapon_id: int, actor_id: int, owner_body: CoCollider, angle: float):
	var projectile_ent: Entity = StaticData.en_scn_rocket.instantiate() as Entity
	
	# register entity and add it to the scene
	var world = ECS.find_world_up(owner_body)
	if world:
		ECS.add_entity(world, projectile_ent)
		world.add_entity_node(projectile_ent)
	#ECSRootManagerSingleton.add_entity_node(projectile_ent)

	# Cast until entity scene typing is implemented in the ECS library
	# setup projectile entity

	var velocity = projectile_ent.get_component(CoVelocity.label) as CoVelocity
	#var area_node: Area2D = projectile_ent.get_component(CoArea.label) as Area2D
	var pro_data: CoProjectileData = projectile_ent.get_component(CoProjectileData.label) as CoProjectileData

	(projectile_ent as Node as Node2D).global_position = (owner_body as Node as Node2D).global_position
	velocity.velocity = Vector2.from_angle(angle) * StaticData.entity.Weapons[weapon_id].projectile_speed
	pro_data.weapon_id = weapon_id as StaticData.WEAPON
	pro_data.owner_actor_id = actor_id



func bullet_raycast(weapon_id: int, raycast: RayCast2D, angle: float, reach: float):
	var entity = bullet_raycast_get_entity(raycast, angle, reach)
	if not entity:
		return
	if not entity.has_component(CoHealth.label):
		return
	var damage = StaticData.entity.Weapons[weapon_id].damage
	print("DAMAGE entity: %s for damage: %s" % [entity, damage])
	HealthUtils.generate_health_damage_event(entity, damage, 0)
	
	
func bullet_raycast_get_entity(raycast: RayCast2D, angle: float, reach: float) -> Entity:
	raycast.target_position = Vector2.from_angle(angle) * reach
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider_node = raycast.get_collider() as Node2D
		print("raycast collided with node ", collider_node)

		if collider_node as Component:
			var collider_entity = ECSUtils.get_entity_from_component(collider_node as Component) 
			return collider_entity

	return null
