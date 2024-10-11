extends System
class_name SyTicks


func _ready():
	components = "%s" % [CoTicks.label]
	super()


func on_process(_entities, _delta: float):
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	if co_ticks:
		co_ticks.ticks += 1
