extends Node


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	"""
	# Using the JsonClassConverter 
	var player = StaticData.new()
	player.Player = StaticPlayer.new()
	player.Player.max_health = 10

	var weapon = StaticWeapon.new()
	weapon.damage = 88
	player.Weapons.append(weapon)

	# Save to file
	#JsonClassConverter.store_json_file("user://player.sav", JsonClassConverter.class_to_json(player))

	# Load from file
	var new_player : StaticData = JsonClassConverter.json_file_to_class(StaticData, "res://data/data.json")
	if new_player:
		print(new_player) # Prints: Bob
		print(new_player.Player.max_health)
		print(JsonClassConverter.class_to_json(new_player))
		print(new_player.Weapons[0].damage)
		"""
	
	print(StaticData.singleton.Player.max_health)
	print(StaticData.singleton.Weapons[StaticData.WEAPON.ROCKET].damage)
