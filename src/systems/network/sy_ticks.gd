extends System
class_name SyTicks


func _ready():
	components = "%s" % [CoTicks.label]
	super()


func on_process(_entities, _delta: float):

	var single_ticks = ECS.get_singleton_entity(self, "EnSingleTicks")
	if not single_ticks:
		print("E: Couldn't find ticks singleton EnSingleTicks")
		return

	# advance once
	var co_ticks = single_ticks.get_component(CoTicks.label) as CoTicks
	co_ticks.ticks += 1
	return
