extends System
class_name SyNetBufferedInputs

## * Buffers the inputs per tick


func _ready():
	components = "%s,%s,%s" % [CoActorInput.label, CoFlagNetSelfPredict.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	for entity: Entity in entities:

		var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
		var co_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# save inputs

		var curr_input = co_actor_input.copy()
		curr_input.tick = co_ticks.ticks
		co_buffered_inputs.set_tick(co_ticks.ticks, curr_input)
