extends System
class_name SyPlayerInputReset
const label: StringName = StringName("SyPlayerInputReset")

## Reset all inputs to defaults

func _ready():
	components = [
		CoActorInput.label,
		CoPlayerInput.label,
		CoWyncEvents.label,
	]
	super()
	
func on_process_entity(entity: Entity, _data, _delta: float):
	var input = entity.get_component(CoActorInput.label) as CoActorInput

	# reset inputs here, see subtick system for polling

	input.movement_dir_prev = input.movement_dir
	input.movement_dir = Vector2(
		int(Input.is_action_pressed("p1_right")) - int(Input.is_action_pressed("p1_left")),
		int(Input.is_action_pressed("p1_down")) - int(Input.is_action_pressed("p1_up")),
	)
	input.shoot = false
	input.reload = false
	input.open_store = false
	
	# TODO: Maybe move this elsewhere
	# Cleaning events from previous tick
	
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	co_wync_events.events.clear()
