extends System
class_name SySwitchWeapon
const label: StringName = StringName("SySwitchWeapon")

func _ready():
	components = [CoWeaponInventory.label, CoWeaponHeld.label, CoActorInput.label]
	super()
	
func on_process_entity(entity: Entity, _data, _delta: float):
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	var weapon_held = entity.get_component(CoWeaponHeld.label) as CoWeaponHeld
	var inventory = entity.get_component(CoWeaponInventory.label) as CoWeaponInventory

	if input.switch_weapon_to < 0:
		return

	if weapon_held.weapon_id == input.switch_weapon_to:
		input.switch_weapon_to = -1
		return

	# find WeaponStored to update
	# with this we avoid switching to weapons we don't have

	var weapon_stored: CoWeaponStored = null
	for w: CoWeaponStored in inventory.inventory:
		if w.weapon_id == input.switch_weapon_to:
			weapon_stored = w
			break
	if weapon_stored == null:
		print("D: SySwitchWeapon: You don't have weapon ", StaticData.entity.Weapons[input.switch_weapon_to].name)
		input.switch_weapon_to = -1
		return

	# NOTE: May want to avoid switching to empty weapons
	# overwrite and cancel reload

	input.switch_weapon_to = -1
	weapon_held.weapon_id = weapon_stored.weapon_id
	weapon_held.reloading = false
	weapon_held.time_started_reloading = 0
	weapon_held.once_event_attacking = false
