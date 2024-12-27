extends System
class_name SyNetSelfPredict
const label: StringName = StringName("SyNetSelfPredict")

## * Only predict movement


func _ready():
	components = [CoNetConfirmedStates.label, CoNetPredictedStates.label, CoFlagNetSelfPredict.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var target_tick = co_predict_data.target_tick
	
	# predict entities

	for entity: Entity in entities:
		
		var co_net_confirmed_states = entity.get_component(CoNetConfirmedStates.label) as CoNetConfirmedStates
		var co_net_predicted_states = entity.get_component(CoNetPredictedStates.label) as CoNetPredictedStates
		var co_net_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs
		
		var last_confirmed = co_net_confirmed_states.buffer.get_relative(0) as NetTickData
		
		if last_confirmed == null:
			continue
		
		# Initialize stored predicted states. TODO: Move elsewhere
		
		if co_net_predicted_states.curr.data == null:
			co_net_predicted_states.curr.data = CoCollider.SnapData.new()
			co_net_predicted_states.prev = co_net_predicted_states.curr.copy()
			continue
		
		# Reset state

		var collider = entity.get_component(CoCollider.label) as CoCollider
		collider.global_position = last_confirmed.data.position as Vector2
		collider.velocity = last_confirmed.data.velocity as Vector2
		
		# predict ticks
		
		for tick in range(last_confirmed.tick +1, target_tick +1):

			var input = null
			var tick_local = co_net_buffered_inputs.get_tick_predicted(tick)
			if tick_local:
				input = co_net_buffered_inputs.get_tick(tick_local)
			if not input:
				input = CoActorInput.new()
			
			#SyActorMovement.simulate_movement(input, collider, _delta)
			
			# store predicted states
			# (run on last two iterations)
			
			if tick > (target_tick -1):
				co_net_predicted_states.prev.data.position = co_net_predicted_states.curr.data.position
				co_net_predicted_states.curr.data.position = collider.global_position
				
			# debug player trail
			
			var progress = (float(tick) - last_confirmed.tick) / (target_tick - last_confirmed.tick)
			DebugPlayerTrail.spawn(self, collider.global_position, progress)

		# update store predicted state metadata
		
		co_net_predicted_states.prev.tick = target_tick -1
		co_net_predicted_states.curr.tick = target_tick
