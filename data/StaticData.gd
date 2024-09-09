extends Node
class_name StaticData

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

static var entity: EntityData

# list reusable entities
static var en_scn_player: PackedScene = preload("res://src/entities/en_player.tscn")
static var en_scn_rocket: PackedScene = preload("res://src/entities/en_rocket.tscn")

func _ready():
	StaticData.entity = JsonClassConverter.json_file_to_class(EntityData, "res://data/data.json")
