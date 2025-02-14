class_name CoCollider
extends Component
static var label = ECS.add_component()

## CoCollider must be initialized to setup their layers and masks
var initialized: bool = false


## If not initialized by their creator, initialize itself
func _ready():
	PhysicsUtils.initialize_collider(self)	
