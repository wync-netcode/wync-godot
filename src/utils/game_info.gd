class_name GameInfo

## Custom entity types

enum {
	ENTITY_TYPE_BALL,
	ENTITY_TYPE_PLAYER,
	ENTITY_TYPE_GRID_PREDICTED,
	ENTITY_TYPE_GRID_DELTA,
	ENTITY_TYPE_GRID_DELTA_PREDICTED,
	ENTITY_TYPE_PROJECTILE,
}

## Blueprints for _delta props_

static var BLUEPRINT_ID_BLOCK_GRID_DELTA = -1

enum {
	EVENT_NONE,

	# delta events
	EVENT_DELTA_BLOCK_REPLACE,

	# player events
	EVENT_PLAYER_SHOOT,
	EVENT_PLAYER_BLOCK_BREAK,
	EVENT_PLAYER_BLOCK_PLACE,
	EVENT_PLAYER_BLOCK_BREAK_DELTA,
	EVENT_PLAYER_BLOCK_PLACE_DELTA,
	EVENT_PLAYER_BLOCK_SET_FIRE,

	# ???
	EVENT_CHAT_MESSAGE,
}

## The user has it's own packet types, he must use a magic number to distinguish 
## his packets from Wync's packets

enum {
	NETE_PKT_ANY,
	NETE_PKT_AMOUNT,
	NETE_PKT_WYNC_PKT = 888
}

## Spawn Data
## --------------------------------------------------------------------------------

class EntityProjectileSpawnData:
	var weapon_id: int
