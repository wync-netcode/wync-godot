extends System
class_name SyWyncTickStart
const label: StringName = StringName("SyWyncTickStart")

## Wync needs to run some things at the start of a game tick

var buffered_inputs = SyWyncBufferedInputs.new()

func on_process(_entities, _data, _delta: float):
	buffered_inputs.on_process([], null, _delta, self)
