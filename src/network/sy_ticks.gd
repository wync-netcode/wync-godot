extends System
class_name SyTicks
const label: StringName = StringName("SyTicks")


func _ready():
	components = [CoTicks.label]
	super()


func on_process(_entities, _data, _delta: float):
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	if co_ticks:
		co_ticks.ticks += 1
