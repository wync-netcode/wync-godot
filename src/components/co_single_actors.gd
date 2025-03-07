extends Component
class_name CoSingleActors
static var label = ECS.add_component()

## Ring buffer to keep track of actors

## Ring<entity_id: int, entity_obj: Entity>
var actors: Array[Entity]
var cursor: int = 0
var actor_count: int = 0
const max_actors: int = 15


func _init() -> void:
	actors.resize(max_actors)
