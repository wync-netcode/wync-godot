extends Component
class_name CoSingleActors
static var label = "cosingleactors"

var actors: Array[Entity]
var cursor: int = 0
var actor_count: int = 0
const max_actors: int = 4


func _ready() -> void:
	actors.resize(max_actors)
