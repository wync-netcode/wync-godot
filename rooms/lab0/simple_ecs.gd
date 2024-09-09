extends Node

func _ready() -> void:
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
	var melee = CoWeaponStored.new()
	melee.weapon_id = StaticData.singleton.WEAPON.PISTOL
	melee.bullets_total_left = 30
	melee.bullets_magazine_left = 20
	inventory.inventory.append(melee)
	var held_weapon = player.get_component("coweaponheld") as CoWeaponHeld
	held_weapon.weapon_id = melee.weapon_id
	print(inventory)


func _process(delta):
	#ECS.update()
	pass
	
func _physics_process(delta: float) -> void:
	ECS.update()
	pass
	
