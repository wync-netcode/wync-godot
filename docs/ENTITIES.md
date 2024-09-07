
# Entities && Components

Only entities here.

## Player
* ActorId
* Position
* Velocity
* Collider
* ActorRenderer

* PlayerInput
* Input
* Health
* WeaponInventory
* HeldWeapon

* Shield
* Money

## RegularZombie: Tank, Worm
* ActorId
* Position
* Velocity
* Collider
* ActorRenderer

* AIInput
* Input
* Health
* HeldWeapon

## ExplosiveZombie
* (extends RegularZombie)
* ExplosiveZombieTag

## Store
* Position
* Collider
* StoreWeaponInventory
* StoreData

## Rocket
* ActorId
* Position
* Velocity
* Collider
* ProjectileData
* ProjectileRenderer

## Explosion
* ActorId
* Position
* CircleCollider
* ExplosionData

## Spawner
* Position
* SpawnerData


# Singleton Entities

Singletons hold global state.

## ActorCounterSingleton
* ActorCount

## RoundTrackerSingleton
* RoundTracker

## PlayerTrackerSingleton
* PlayerTracker
