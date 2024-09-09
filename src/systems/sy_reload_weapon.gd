extends System
class_name SyReloadWeapon

func _ready():
	components = "CoWeaponInventory,CoWeaponHeld,CoActorInput"
	super()
	
func on_process_entity(entity: Entity, _delta: float):
	var input = entity.get_component("coactorinput") as CoActorInput
	var weapon_held = entity.get_component("coweaponheld") as CoWeaponHeld
	var inventory = entity.get_component("coweaponinventory") as CoWeaponInventory
	var curr_time = Time.get_ticks_msec()

	# find WeaponStored to update

	var weapon_stored: CoWeaponStored = null
	for w: CoWeaponStored in inventory.inventory:
		if w.weapon_id == weapon_held.weapon_id:
			weapon_stored = w
			break
	if weapon_stored == null:
		return

	# finish reload

	var magazine_size = StaticData.singleton.Weapons[weapon_stored.weapon_id].magazine_size
	var finished_reloading = curr_time - weapon_held.time_started_reloading >= StaticData.singleton.Weapons[weapon_held.weapon_id].reload_delay

	if weapon_held.reloading and finished_reloading:
		weapon_held.reloading = false

		var prev_magazine = weapon_stored.bullets_magazine_left
		weapon_stored.bullets_magazine_left = min(weapon_stored.bullets_magazine_left + weapon_stored.bullets_total_left, magazine_size)
		weapon_stored.bullets_total_left -= weapon_stored.bullets_magazine_left - prev_magazine
		print("Finished reloading ", magazine_size, " ", weapon_stored.bullets_magazine_left, " ", weapon_stored.bullets_total_left)

	# start reloading

	elif (not weapon_held.reloading and input.reload
		and weapon_stored.bullets_magazine_left < magazine_size  # magazine full
		and weapon_stored.bullets_total_left > 0  # no bullets in reserve
		):
		weapon_held.reloading = true
		weapon_held.time_started_reloading = curr_time
		print("Starting reloading")
