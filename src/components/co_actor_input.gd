extends Component
class_name CoActorInput
static var label = ECS.add_component()

var movement_dir: Vector2
var aim: Vector2
var shoot: bool
var reload: bool
var open_store: bool
var switch_weapon_to: int = -1
var tick: int


func copy() -> CoActorInput:
	var newi = CoActorInput.new()
	newi.movement_dir = movement_dir
	newi.aim = aim
	newi.shoot = shoot
	newi.reload = reload
	newi.open_store = open_store
	newi.switch_weapon_to = switch_weapon_to
	newi.tick = tick
	return newi
