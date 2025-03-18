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
	
	func duplicate() -> EntityProjectileSpawnData:
		var newi = EntityProjectileSpawnData.new()
		newi.weapon_id = weapon_id
		return newi

## Events
## --------------------------------------------------------------------------------

class EventPlayerBlockBreak:
	var block_grid_id: String
	var pos: Vector2i

	func duplicate() -> EventPlayerBlockBreak:
		var newi = EventPlayerBlockBreak.new()
		newi.block_grid_id = block_grid_id
		newi.pos = pos
		return newi

class EventDeltaBlockReplace:
	var pos: Vector2i
	var block_id: int

	func duplicate() -> EventDeltaBlockReplace:
		var newi = EventDeltaBlockReplace.new()
		newi.pos = pos
		newi.block_id = block_id
		return newi

class EventPlayerBlockBreakDelta:
	var block_grid_id: String
	var pos: Vector2i

	func duplicate() -> EventPlayerBlockBreakDelta:
		var newi = EventPlayerBlockBreakDelta.new()
		newi.block_grid_id = block_grid_id
		newi.pos = pos
		return newi

class EventPlayerBlockPlaceDelta:
	var block_grid_id: String
	var pos: Vector2i

	func duplicate() -> EventPlayerBlockPlaceDelta:
		var newi = EventPlayerBlockPlaceDelta.new()
		newi.block_grid_id = block_grid_id
		newi.pos = pos
		return newi

class EventPlayerShoot:
	var last_tick_rendered_left: int
	var lerp_delta: float

	func duplicate() -> EventPlayerShoot:
		var newi = EventPlayerShoot.new()
		newi.last_tick_rendered_left = last_tick_rendered_left
		newi.lerp_delta = lerp_delta
		return newi
