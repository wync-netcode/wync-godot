class_name StaticData

var Player: StaticPlayer
var Weapons: Array[StaticWeapon]
var Zombies: Array[StaticZombie]
var Explosion: Array[StaticExplosion]

enum WEAPON {
	MELEE,
	PISTOL,
	UZI
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
