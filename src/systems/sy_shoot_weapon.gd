extends System
class_name SyShootWeapon
const label: StringName = StringName("SyShootWeapon")

func _ready():
	components = [CoActor.label, CoWeaponInventory.label, CoWeaponHeld.label, CoActorInput.label, CoCollider.label]
	super()


func on_process(_entities: Array, _data, _delta: float):
	pass
	#for entity in entities:
	#	simulate_shoot_weapon(self, entity)

	
static func simulate_shoot_weapon(node_ctx: Node, entity: Entity):
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
	var aim_angle: float = collider.global_position.angle_to_point(input.aim)
	var reach: int = 0
	var raycast: RayCast2D = null

	if not is_projectile:
		var raycast_ent = ECS.get_singleton_entity(node_ctx, "EnRaycastSingleton")
		if not raycast_ent:
			Log.err(node_ctx, "SyShootWeapon | E: Couldn't find singleton EnRaycastSingleton")
			return
		var raycast_co = raycast_ent.get_component(CoRaycast.label) as CoRaycast
		raycast = raycast_co as Node as RayCast2D
		reach = raycast_co.default_reach

		if StaticData.entity.Weapons[weapon_stored.weapon_id].reach != 0:
			reach = StaticData.entity.Weapons[weapon_stored.weapon_id].reach

		raycast.clear_exceptions()
		raycast.add_exception(collider as CharacterBody2D)
		raycast.global_position = collider.global_position

	# fire one of the pellets with perfect accuracy

	Log.out(node_ctx, "SyShootWeapon | is_projectile %s %s" % [is_projectile, weapon.weapon_id])
	if pellets > 1:
		pellets -= 1
		if not is_projectile:
			bullet_raycast(node_ctx, weapon.weapon_id, raycast, aim_angle, reach)
		else:
			launch_projectile(weapon.weapon_id, actor.id, collider, aim_angle)

	# fire remaining

	for i in range(pellets):
		var angle = aim_angle + deg_to_rad(spread) * randf_range(-1, 1)
		if not is_projectile:
			bullet_raycast(node_ctx, weapon.weapon_id, raycast, angle, reach)
		else:
			launch_projectile(weapon.weapon_id, actor.id, collider, angle)


static func launch_projectile(weapon_id: int, actor_id: int, owner_body: CoCollider, angle: float):
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


static func bullet_raycast(node_ctx: Node, weapon_id: int, raycast: RayCast2D, angle: float, reach: float):
	var entity = bullet_raycast_get_entity(node_ctx, raycast, angle, reach)
	if entity == null:
		return
	if entity.has_component(CoHealth.label) == null:
		Log.err(node_ctx, "SyShootWeapon | entity doesn't have CoHealth %s" % [entity])
		return
	var damage = StaticData.entity.Weapons[weapon_id].damage
	Log.out(node_ctx, "SyShootWeapon | DAMAGE entity: %s for damage: %s" % [entity, damage])
	HealthUtils.generate_health_damage_event(entity, damage, 0)

	# visual effect
	if entity.has_component(CoCollider.label):
		var co_collider = entity.get_component(CoCollider.label) as CoCollider as Node as Node2D
		DebugParticle.spawn(entity.get_tree().root, co_collider.global_position, Color.FUCHSIA)

	
	
static func bullet_raycast_get_entity(node_ctx: Node, raycast: RayCast2D, angle: float, reach: float) -> Entity:
	raycast.target_position = Vector2.from_angle(angle) * reach
	raycast.force_raycast_update()
	
	if raycast.is_colliding():
		var collider_node = raycast.get_collider() as Node2D
		Log.out(node_ctx, "SyShootWeapon | raycast collided with node %s" % [collider_node])

		if collider_node is Component:
			var collider_entity = ECSUtils.get_entity_from_component(collider_node as Component) 
			if collider_entity == null:
				Log.err(node_ctx, "SyShootWeapon | couldn't find entity for component %s" % [collider_node])
			return collider_entity
		else:
			Log.err(node_ctx, "SyShootWeapon | collider_node is not a Component %s" % [collider_node])

	return null
