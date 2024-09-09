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
	# account for weapon reach

	var raycast_ent = EntitySingletons.singleton.get_entity("EnRaycastSingleton")
	var raycast = raycast_ent.get_component("coraycast") as RayCast2D
	var ray_dir = node2d.global_position.direction_to(input.aim)
	var reach = (raycast as CoRaycast).default_reach
	if StaticData.singleton.Weapons[weapon_stored.weapon_id].reach != 0:
		reach = StaticData.singleton.Weapons[weapon_stored.weapon_id].reach
	
	raycast.global_position = node2d.global_position
	raycast.target_position = ray_dir * reach
	
	raycast.clear_exceptions()
	raycast.add_exception(collider as CharacterBody2D)
	raycast.force_raycast_update()
	if not raycast.is_colliding():
		return
	var ray_collider = raycast.get_collider() as Node2D
	print("collider ", ray_collider)


	# TODO: find a more elegant way of doing this
	var collider_entity = ECSUtils.get_entity_from_component(ray_collider as Component)
	print("collider entity ", collider_entity)
	
