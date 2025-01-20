extends Component
class_name CoActorInput
static var label = ECS.add_component()

var movement_dir: Vector2
var aim: Vector2
var shoot: bool
var reload: bool
var open_store: bool
var switch_weapon_to: int = -1


func copy() -> CoActorInput:
	var newi = CoActorInput.new()
	newi.movement_dir = movement_dir
	newi.aim = aim
	newi.shoot = shoot
	newi.reload = reload
	newi.open_store = open_store
	newi.switch_weapon_to = switch_weapon_to
	return newi


func copy_to_instance(ins: CoActorInput) -> void:
	ins.movement_dir = movement_dir
	ins.aim = aim
	ins.shoot = shoot
	ins.reload = reload
	ins.open_store = open_store
	ins.switch_weapon_to = switch_weapon_to
