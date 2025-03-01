extends Component
class_name CoRaycast
static var label = ECS.add_component()

const default_reach: float = 2000

## CoRaycast must be initialized to setup it's masks depending on the world
var initialized: bool = false

## If not initialized by their creator, initialize itself
func _ready():
	PhysicsUtils.initialize_raycast_layers(self)	
