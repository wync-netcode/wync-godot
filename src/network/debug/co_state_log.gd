extends Component
class_name CoStateLog
static var label = ECS.add_component()

class State:
	var tick: int
	var pos: Vector2
	var vel: Vector2
	var input: float

# Dictionary<tick: int, position: Vector2>
var server_state: Dictionary = {}
var client_state: Dictionary = {}
