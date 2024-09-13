
# Entities && Components

Only entities here.

## Player
* ActorId
* Position
* Velocity
* Collider
* ActorRenderer

* PlayerInput
* ActorInput
* Health
* WeaponInventory
* WeaponHeld

* Shield
* Money

## RegularZombie: Tank, Worm
* ActorId
* Position
* Velocity
* Collider
* ActorRenderer

* AIInput
* ActorInput
* Health
* WeaponHeld

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

## RaycastSingleton
* Raycast

# Networking Entities

## EnSingleTicks
* CoTicks

Keeps track of game ticks


## EnSingleTransportLoopback
* CoTransportLoopback


## EnSingleServer
* CoIOPackets # leaving / incoming pkts
* CoServer
    state: int
    peers: Array[ServerPeer]
    peer_count: int

    #### ServerPeer
    identifier: int
    peer_id: int # key to actual peer

## EnClient
* CoIOPackets # leaving / incoming pkts
* CoSnapshots
* CoClient # contains server peer connection identifier (void*)
    state: int
    identifier: int
    server_peer: int # key to actual peer
