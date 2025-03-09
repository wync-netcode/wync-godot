extends System
class_name SyPlayerInputAdditive
const label: StringName = StringName("SyPlayerInputAdditive")

## NOTE: This service might be redundant, since we're always gonna
##     read inputs on _process (subtick)...
## This system might run multiples times on frame ticks, or physics ticks

func _ready():
	components = [
		CoActorInput.label,
		CoPlayerInput.label,
		CoWyncEvents.label,
	]
	super()
	
func on_process_entity(entity: Entity, _data, _delta: float):
	SyPlayerSubtickInputAdditive.player_input_additive(self, entity)
