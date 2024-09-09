

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

### WeaponInventory
Inventory: Array[CoWeaponStored]

### WeaponStored (never used as a component)
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

