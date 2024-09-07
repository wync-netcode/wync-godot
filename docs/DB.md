
# DataBase Structures

Data structures for static data only.

### Weapon
* id: enum
* name: string
* pellet_count: int
* magazine_size: int
* spread: int
* shoot_delay: int
* reload_delay: int
* bullet_type: enum (raycast or projectile)
* damage: int
* weapon_price: int
* ammunition_price: int
* ammunition_size: int
* reach: int # only for melee
* projectile_speed: float # only for projectile
* projectile_sprite: RID

### Player
* max_health: int
* acc: float
* friction: float
* max_speed: float
* sprite: RID

### Zombie
* id: enum
* name: string
* acc: float
* friction: float
* max_speed: float
* max_health: int
* money_reward: int
* max_minions: int
* sprite: RID

### Explosion
* id: enum
* radious: int

### Shield
* shield_duration: int

# Static Intances

Instances of static data only. Do not confuse with entity instances.

### PlayerResources

### Weapon: Melee
### Weapon: Pistol
### Weapon: UZI
### Weapon: Shotgun
### Weapon: Rocket

### Zombie: Regular
### Zombie: Tank
### Zombie: Explosive
### Zombie: Worm

### Explosion: Rocket
### Explosion: Zombie

### Shield: Player

