

# Systems

Behaviour only.

## PlayerInputSys
* PlayerInput
* Input

It fills player inputs

## AIInputSys
* AIInput
* Input
* Position
* (undirectly) PlayerTrackerSingleton

Uses pathfinding to generate AI inputs

## ActorMovementSys
* ActorId
* Position
* Velocity
* Collider

Moves actors like players and zombies

## ProjectileMovementSys
* Position
* Velocity
* Collider
* ProjectileData

Moves projectiles

## ReloadWeaponSys
* WeaponInventory
* HeldWeapon
* Input
* (undirectly) StoredWeapon

Handles reloading a weapon

## ShootWeaponSys
* WeaponInventory
* HeldWeapon
* Input
* (undirectly) StoredWeapon
* (undirectly) Collider
* (undirectly) Health

- Handles weapon shooting: Raycast, Projectiles.
- Should we buffer shots?
- If collided with actor need to get health component.

## ExplosionsSys
* ActorId
* Position
* CircleCollider
* ExplosionData
* (undirectly) Collider
* (undirectly) Health

- Affects nearby actors.
- If collided with actor need to get health component.

## SpawnerSys
* Position
* SpawnerData
* RoundTrackerSingleton

Spawns enemies.

## StoreSys
* PlayerInput
* Collider
* WeaponInventory
* (Indirectly) StoredWeapon
* (Indirectly) Player entity's collider

- Opens on proximity.
- Allows to buy weapons and ammo.

## HUDSys
* HUDData
* PlayerTrackerSingleton
* RoundTrackerSingleton

Updates the HUD. i.e. On screen, health, ammo, etc.
