

# Systems

Behaviour only.

## SyPlayerInput
* PlayerInput
* Input

It fills player inputs

## SyAIInput
* AIInput
* Input
* Position
* (undirectly) PlayerTrackerSingleton

Uses pathfinding to generate AI inputs

## SyActorMovement
* ActorId
* Position
* Velocity
* Collider

Moves actors like players and zombies

## SyProjectileMovement
* Position
* Velocity
* Collider
* ProjectileData

Moves projectiles

## SyReloadWeapon
* WeaponInventory
* WeaponHeld
* Input
* (undirectly) WeaponStored

Handles reloading a weapon

## SyShootWeapon
* WeaponInventory
* WeaponHeld
* Input
* (undirectly) WeaponStored
* (undirectly) Collider
* (undirectly) Health

- Handles weapon shooting: Raycast, Projectiles.
- Should we buffer shots?
- If collided with actor need to get health component.

## SyExplosions
* ActorId
* Position
* CircleCollider
* ExplosionData
* (undirectly) Collider
* (undirectly) Health

- Affects nearby actors.
- If collided with actor need to get health component.

## SySpawner
* Position
* SpawnerData
* RoundTrackerSingleton

Spawns enemies.

## SyStore
* PlayerInput
* Collider
* WeaponInventory
* (Indirectly) WeaponStored
* (Indirectly) Player entity's collider

- Opens on proximity.
- Allows to buy weapons and ammo.

## SyHUD
* HUDData
* PlayerTrackerSingleton
* RoundTrackerSingleton

Updates the HUD. i.e. On screen, health, ammo, etc.
