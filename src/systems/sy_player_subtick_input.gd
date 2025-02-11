extends System
class_name SyPlayerSubtickInput
const label: StringName = StringName("SyPlayerSubtickInput")

## Only some inputs are subject to subtick accuracy

func _ready():
	components = [
		CoActorInput.label,
		CoPlayerInput.label,
		CoWyncEvents.label,
	]
	super()
	
func on_process_entity(entity: Entity, _data, _delta: float):
	var input = entity.get_component(CoActorInput.label) as CoActorInput

	# Note: Maybe add movement_dir
	input.shoot = input.shoot || Input.is_action_pressed("p1_mouse1")
	input.reload = input.reload || Input.is_action_pressed("p1_reload")
	input.open_store = input.open_store || Input.is_action_pressed("p1_interact")
	input.aim = (entity as Node as Node2D).get_global_mouse_position()

	if Input.is_action_pressed("p1_weapon1"): input.switch_weapon_to = 0
	elif Input.is_action_pressed("p1_weapon2"): input.switch_weapon_to = 1
	elif Input.is_action_pressed("p1_weapon3"): input.switch_weapon_to = 2
	elif Input.is_action_pressed("p1_weapon4"): input.switch_weapon_to = 3
	elif Input.is_action_pressed("p1_weapon5"): input.switch_weapon_to = 4
