extends ECSRoot

func _ready() -> void:
	super()
	
	Logger.set_logger_level(Logger.LOG_LEVEL_NONE)
	ECS.update()
	
	# create player
	var player_scene: PackedScene = preload("res://src/entities/en_player.tscn")
	var player = player_scene.instantiate() as Entity
	ECS.add_entity(player)
	add_child(player)
	print(player)

	# give it a weapon
	var inventory = player.get_component("coweaponinventory") as CoWeaponInventory
	
	var w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.MELEE
	inventory.inventory.append(w)
	
	w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.PISTOL
	w.bullets_total_left = 300
	w.bullets_magazine_left = 2
	inventory.inventory.append(w)

	w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.UZI
	w.bullets_total_left = 300
	w.bullets_magazine_left = 2
	inventory.inventory.append(w)

	w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.SHOTGUN
	w.bullets_total_left = 300
	w.bullets_magazine_left = 2
	inventory.inventory.append(w)

	w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.ROCKET
	w.bullets_total_left = 300
	w.bullets_magazine_left = 1
	inventory.inventory.append(w)
	
	var held_weapon = player.get_component("coweaponheld") as CoWeaponHeld
	held_weapon.weapon_id = w.weapon_id
	print(inventory)


func _process(delta):
	#ECS.update()
	pass
	
func _physics_process(delta: float) -> void:
	ECS.update()
	pass
	
