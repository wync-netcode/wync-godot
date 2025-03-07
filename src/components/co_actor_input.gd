extends Component
class_name CoActorInput
static var label = ECS.add_component()

var movement_dir_prev: Vector2
var movement_dir: Vector2
var aim: Vector2
var shoot: bool
var reload: bool
var open_store: bool
var switch_weapon_to: int = -1

class PortableCopy:
	var movement_dir_prev: Vector2
	var movement_dir: Vector2
	var aim: Vector2
	var shoot: bool
	var reload: bool
	var open_store: bool
	var switch_weapon_to: int = -1

	func copy() -> PortableCopy:
		var newi = PortableCopy.new()
		newi.movement_dir_prev = movement_dir_prev
		newi.movement_dir = movement_dir
		newi.aim = aim
		newi.shoot = shoot
		newi.reload = reload
		newi.open_store = open_store
		newi.switch_weapon_to = switch_weapon_to
		return newi


func copy() -> PortableCopy:
	var newi = PortableCopy.new()
	newi.movement_dir_prev = movement_dir_prev
	newi.movement_dir = movement_dir
	newi.aim = aim
	newi.shoot = shoot
	newi.reload = reload
	newi.open_store = open_store
	newi.switch_weapon_to = switch_weapon_to
	return newi


func set_from_instance(ins: PortableCopy) -> void:
	movement_dir_prev = ins.movement_dir_prev
	movement_dir = ins.movement_dir
	aim = ins.aim
	shoot = ins.shoot
	reload = ins.reload
	open_store = ins.open_store
	switch_weapon_to = ins.switch_weapon_to
