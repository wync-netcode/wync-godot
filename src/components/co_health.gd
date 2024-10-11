extends Component
class_name CoHealth
static var label = ECS.add_component()

@export var max_health: int
@export var health: int
var damage_events: Array[CoHealthDamageEvent]
