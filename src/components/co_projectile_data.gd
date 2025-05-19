extends Component
class_name CoProjectileData
static var label = ECS.add_component()

var alive: bool = true
var ticks_alive: int = 0
var owner_actor_id: int = -1
@export var weapon_id: StaticData.WEAPON
