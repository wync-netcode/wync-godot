extends ECSRoot

@onready var world_server: World = $WorldServer
@onready var world_client_1: World = $WorldClient1
var counter = 0

func _ready() -> void:
	super()
	
	Logger.set_logger_level(Logger.LOG_LEVEL_NONE)
	ECS.update(world_server)
	ECS.update(world_client_1)
	
	# create player
	var player_scene: PackedScene = preload("res://src/entities/en_player.tscn")
	var player = player_scene.instantiate() as Entity
	ECS.add_entity(world_server, player)
	world_server.add_child(player)
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
	
	# the other player
	
	inventory = world_client_1.get_node("Entities/EnPlayer2").get_component("coweaponinventory") as CoWeaponInventory
	
	w = CoWeaponStored.new()
	w.weapon_id = StaticData.WEAPON.ROCKET
	w.bullets_total_left = 300
	w.bullets_magazine_left = 1
	inventory.inventory.append(w)
	
	held_weapon = world_client_1.get_node("Entities/EnPlayer2").get_component("coweaponheld") as CoWeaponHeld
	held_weapon.weapon_id = w.weapon_id


func _process(delta):
	pass


func _physics_process(delta: float) -> void:
	ECS.update(world_server)
	ECS.update(world_client_1)
	
	counter += 1
	if counter % 3 == 0:
		#ECS.update(world_client_1)
		pass
 
