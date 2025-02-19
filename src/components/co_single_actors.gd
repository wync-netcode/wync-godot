extends Component
class_name CoSingleActors
static var label = ECS.add_component()

## Ring buffer to keep track of actors

var actors: Array[Entity]
var cursor: int = 0
var actor_count: int = 0
const max_actors: int = 5


func _ready() -> void:
	actors.resize(max_actors)
