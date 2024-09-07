extends Node
class_name StaticData

var Player: StaticPlayer
var Weapons: Array[StaticWeapon]
var Zombies: Array[StaticZombie]
var Explosion: Array[StaticExplosion]

enum WEAPON {
	MELEE,
	PISTOL,
	SHOTGUN,
	UZI,
	ROCKET
}

enum ZOMBIE {
	REGULAR,
	TANK,
	EXPLOSIVE,
	WORM
}

enum EXPLOSION {
	ROCKET,
	ZOMBIE
}

static var singleton: StaticData

func _ready():
	StaticData.singleton = JsonClassConverter.json_file_to_class(StaticData, "res://data/data.json")
