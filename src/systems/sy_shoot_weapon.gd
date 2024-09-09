extends System
class_name SyShootWeapon

func _ready():
	components = "CoWeaponInventory,CoWeaponHeld,CoActorInput,CoCollider"
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var node2d = entity as Node as Node2D
	var input = entity.get_component("coactorinput") as CoActorInput
	var weapon = entity.get_component("coweaponheld") as CoWeaponHeld
	var inventory = entity.get_component("coweaponinventory") as CoWeaponInventory
	var collider = entity.get_component("cocollider") as CoCollider

	# shooting

	if not input.shoot:
		return

	# find WeaponStored

	var weapon_stored: CoWeaponStored = null
	for w: CoWeaponStored in inventory.inventory:
		print("CoWeaponStored ", w)
		print("w.weapon_id", w.weapon_id)
		
		if w.weapon_id == weapon.weapon_id:
			weapon_stored = w
			break

	print("weapon_stored", weapon_stored)
	if weapon_stored == null:
		return
	
	
	# delay / cooldown between shots
	
	var current_time = Time.get_ticks_msec()
	if current_time - weapon_stored.time_last_shot < StaticData.singleton.Weapons[weapon_stored.weapon_id].shoot_delay:
		return
	weapon_stored.time_last_shot = Time.get_ticks_msec()

	# enough bullets

	var has_bullets = weapon_stored.bullets_magazine_left > 0
	var is_melee = weapon.weapon_id == StaticData.singleton.WEAPON.MELEE
	if not (has_bullets || is_melee):
		return
	if has_bullets:
		weapon_stored.bullets_magazine_left -= 1

	# perform raycast
	# + account for weapon reach

	var raycast_ent = EntitySingletons.singleton.get_entity("EnRaycastSingleton")
	var raycast_co = raycast_ent.get_component("coraycast") as CoRaycast
	var raycast: RayCast2D = raycast_co as Node as RayCast2D
	var pellets: int = StaticData.singleton.Weapons[weapon.weapon_id].pellet_count
	var spread: int = StaticData.singleton.Weapons[weapon.weapon_id].spread_deg
	var aim_angle: float = node2d.global_position.angle_to_point(input.aim)
	var reach = raycast_co.default_reach
	if StaticData.singleton.Weapons[weapon_stored.weapon_id].reach != 0:
		reach = StaticData.singleton.Weapons[weapon_stored.weapon_id].reach

	raycast.clear_exceptions()
	raycast.add_exception(collider as CharacterBody2D)
	raycast.global_position = node2d.global_position

	# make one of the pellets have perfect accuracy

	if pellets > 1:
		bullet_raycast(weapon.weapon_id, raycast, aim_angle, reach)
		pellets -= 1

	# calculate the rest

	for i in range(pellets):
		var angle = aim_angle + deg_to_rad(spread) * randf_range(-1, 1)
		bullet_raycast(weapon.weapon_id, raycast, angle, reach)


func bullet_raycast(weapon_id: int, raycast: RayCast2D, angle: float, reach: float):
	var entity = bullet_raycast_get_entity(raycast, angle, reach)
	if not entity:
		return
	if not entity.has_component(CoHealth.label):
		return
	var damage = StaticData.singleton.Weapons[weapon_id].damage
	print("DAMAGE entity: %s for damage: %s" % [entity, damage])
	
	
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
