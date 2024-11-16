extends System
class_name SyNetPredictionTicks
const label: StringName = StringName("SyNetPredictionTicks")

## * Advances the local game tick and the predicted game tick


func _ready():
	# TODO: Define so that it doesn't depend on spawned entities
	components = [CoNetConfirmedStates.label, CoNetPredictedStates.label, CoFlagNetSelfPredict.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var curr_time = Time.get_ticks_msec()
	var physics_fps = Engine.physics_ticks_per_second
	
	# define target time to render
	# TODO: Extract from engine or define elsewhere
	#var tick_rate = physics_fps / 10.0
	# TODO: The server should communicate this information
	# NOTE: What if we have different send rates for different entities as a LOD measure?
	#var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) 
	# TODO: How to define the padding? Maybe it should be a display tick?

	#var padding = (1000.0 / tick_rate)
	#var target_time = curr_time - pkt_inter_arrival_time - padding
	var target_time = curr_time + co_loopback.lag * 2 + (1000.0 / physics_fps) * 3 + 200

	# adjust periodically to compensate for unstable ping
	
	if co_ticks.ticks % 30 == 0:
		var target_tick = co_predict_data.last_tick_confirmed + ceil((target_time - co_predict_data.last_tick_timestamp) / float(1000.0 / physics_fps))
		co_predict_data.tick_offset = target_tick - co_ticks.ticks
		Log.out(self, "Updating tick offset to %s" % co_predict_data.tick_offset)
	
	co_predict_data.target_tick = co_ticks.ticks + co_predict_data.tick_offset
	# TODO: Sumar 1 o no sumar 1 a target_tick?

	#Log.out(self, "target_time %s last_tick %s target_tick %s" % [target_time, co_predict_data.last_tick_confirmed, target_tick])
