class_name CoCollider
extends Component
static var label = "cocollider"

## CoCollider must be initialized to setup their layers and masks
var initialized: bool = false


## If not initialized by their creator, initialize itself
func _ready():
	PhysicsUtils.initialize_collider(self)	

## Network serialized data
class SnapData:
	var position: Vector2
	var velocity: Vector2

	## NOTE: Isn't there a better way to do this? Maybe through reflection?
	func copy() -> SnapData:
		var newi = SnapData.new()
		newi.position = position
		newi.velocity = velocity
		return newi
