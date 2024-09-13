

# Components

Components refer to dynamic instances.

### ActorId
actor_id: int

### Position
position: Vector2

### Velocity
velocity: Vector2

### Collider
rect: Rect2D

### Health
max_health: int
health: int
damage_events: Array[HealthDamageEvent]

### HealthDamageEvent (subcomponent)
damage: int
player_id: int

### Shield
shield_active: bool
time_shield_activated: int

### PlayerInput
void

### ActorInput
movement_dir: Vector2
aim: Vector2
shoot: bool
reload: bool
open_store: bool
switch_weapon_to: int = -1

### WeaponInventory
Inventory: Array[CoWeaponStored]

### WeaponStored (subcomponent)
weapon_id: enum
bullets_total_left: int
bullets_magazine_left: int
time_last_shot: int # to avoid quick switching
infinite_ammo: bool # for bots

### WeaponHeld
weapon_id: enum
reloading: bool
time_started_reloading: int
once_event_attacking: bool # for animation only

### Money
money: int

### StoreWeaponInventory
Inventory: Array[int] # weapon static ids

### ActorRenderer
sprite: RID

### ProjectileRenderer
sprite: RID

### ProjectileData
weapon_id: enum

### ExplosionData
base_damage: int

### StoreData
open: bool
ui_node: RID

### HUD
ui_node: RID

### SpawnerData

### ExplosiveZombieTag
void

# Components for Singleton entities

### ActorCount
actor_id_count: int

### RoundTracker
enemies_to_spawn: int
enemies_spawned: int
enemies_killed: int
current_round: int

### PlayerTracker
players: Array[PlayerEntity]

### Raycast
raycast: Raycast


# Networking Components

### CoTicks
ticks: int

### CoTransportLoopback
peers: Array[LoopbackPeer] = []  # registered peers
packets: Array[LoopbackPacket] = []  # represent packets flying in the network
lag: int = 0  # (ms)
jitter: int = 0  # (ms) how many frames a package might be late
packet_loss_percentage: int = 0 # [0-100]
time_last_pkt_sent: int = 0
jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets

#### LoopbackPeer
peer_packet_buffer: CoIOPackets # represents the peer location

#### LoopbackPacket
deliver_time: int # ms
data: NetPacket

### CoIOPackets
in_packets: Array[NetPacket]
out_packets: Array[NetPacket]

#### NetPacket
to_peer: int # peer key
data: NetSnapshot

#### NetSnapshot
tick: int
entity_ids: Array[int]
positions: Array[Vector]

### CoSnapshots
entity_snapshots: Map[entity_id: int, position_snapshots: Array<4>[PositionSnapshot]]

#### PositionSnapshot
tick: int
position: Vector2

### CoServer
(see entities.md)

### CoClient
(see entities.md)
