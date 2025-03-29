extends ECSRoot

var worlds: Array[World] = []
var world_ids: Array[int] = []
var worlds_physics_groups: Dictionary = {}
var worlds_process_groups: Dictionary = {}

func _ready() -> void:
	super()
	Logger.set_logger_level(Logger.LOG_LEVEL_NONE)
	
	# get worlds

	for child in get_node("worlds").get_children():
		if child is World:
			worlds.append(child)
			world_ids.append(child.get_instance_id())
			ECS.update(child)

	# get system groups

	for world in worlds:
		for child in world.get_children():
			if child is not Group:
				continue
			if child.name == "GroupProcess":
				worlds_process_groups[world.get_instance_id()] = child
			else:
				worlds_physics_groups[world.get_instance_id()] = child
	
	# create player
	"""
	var player_scene: PackedScene = preload("res://src/entities/en_player.tscn")
	var player = player_scene.instantiate() as Entity
	ECS.add_entity(worlds[0], player)
	worlds[0].add_child(player)
	print(player)

	# place it
	var co_collider = player.get_component(CoCollider.label) as CoCollider
	co_collider.global_position = Vector2(100, 50)
	"""


	"""
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
	"""
	# give players weapons
	
	for world in worlds:
		var player_entity = world.get_node("Entities/EnPlayer") as Entity
		var inventory = player_entity.get_component(CoWeaponInventory.label) as CoWeaponInventory
	
		var w = CoWeaponStored.new()
		w.weapon_id = StaticData.WEAPON.UZI
		w.bullets_total_left = 300
		w.bullets_magazine_left = 10000
		inventory.inventory.append(w)

		w = CoWeaponStored.new()
		w.weapon_id = StaticData.WEAPON.ROCKET
		w.bullets_total_left = 300
		w.bullets_magazine_left = 10000
		inventory.inventory.append(w)
		
		var held_weapon = player_entity.get_component(CoWeaponHeld.label) as CoWeaponHeld
		held_weapon.weapon_id = w.weapon_id


func _process(delta: float) -> void:
	for i: int in range(world_ids.size()):
		ECS.update_group(worlds[i], worlds_process_groups[world_ids[i]], null, delta)


func _physics_process(delta: float) -> void:
	for i: int in range(world_ids.size()):
		ECS.update_group(worlds[i], worlds_physics_groups[world_ids[i]], null, delta)

func _exit_tree() -> void:
	print_orphan_nodes()
	
