

# Systems

Behaviour only.

## SyHealth
* Health

Manages damage events and entity death

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

## SySwitchWeapon
* WeaponInventory
* WeaponHeld
* Input
* (undirectly) WeaponStored

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

# Networking Systems

## SyTransportLoopbackConnection
* CoClient
* CoIOPackets

Singletons:
* EnSingleServer
    * CoIOPackets
    * CoServer

- Clients connect (forcefully) to the singleton server
- Clients are assigned an identifier, client identifiers are managed by the server state

## SyStateExtractor
* CoActor (tag)
* CoCollider

Singletons:
* EnSingleTicks
    * CoTicks
* EnSingleServer
    * CoIOPackets
    * CoServer

- (Server) Compiles game state in a packet and buffers it
- The packet contains data and destination client


## SyTransportLoopback
* CoIOPackets

Singletons:
* EnSingleTransportLoopback
    * CoTransportLoopback

Only Sends and Receives packets from the network

## SyClientProcessPackets
* CoIOPackets
* CoSnapshots

Reads packets to snapshots

