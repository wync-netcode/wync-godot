extends System
class_name SyNetBufferedInputs
const label: StringName = StringName("SyNetBufferedInputs")

## * Buffers the inputs per tick
## Rules for saving a tick
## * Si ya existe no lo reemplaces
## * Solo puedes guardar ticks que sean mayores al último guardado?

func _ready():
	components = [CoActorInput.label, CoFlagNetSelfPredict.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_curr = co_ticks.server_ticks
	var tick_pred = co_predict_data.target_tick

	# TODO: Save actual ticks

	for entity: Entity in entities:

		var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
		var co_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs

		# save inputs

		var curr_input = co_actor_input.copy()
		curr_input.tick = tick_curr
		co_buffered_inputs.set_tick(tick_curr, curr_input)
		
		# save tick relationship
		
		co_buffered_inputs.set_tick_predicted(tick_pred, tick_curr)
