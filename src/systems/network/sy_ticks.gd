extends System
class_name SyTicks

func _ready():
	components = "%s" % [CoTicks.label]
	super()

func on_process(entities, _delta: float):
	for entity: Entity in entities:

		var single_ticks = ECS.get_singleton_entity(entity, "EnSingleTicks")
		if not single_ticks:
			print("E: Couldn't find ticks singleton EnSingleTicks")
			return

		# advance once
		var co_ticks = single_ticks.get_component(CoTicks.label) as CoTicks
		co_ticks.ticks += 1
		return
