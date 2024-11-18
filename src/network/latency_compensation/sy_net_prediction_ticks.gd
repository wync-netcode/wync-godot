extends System
class_name SyNetPredictionTicks
const label: StringName = StringName("SyNetPredictionTicks")

## * Advances the local game tick and the predicted game tick
## NOTE: What if we have different send rates for different entities as a LOD measure?


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
	
	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second
	
	# TODO: Move this DEBUG Random ping variation elsewhere
	
	if co_ticks.ticks % 30 == 0:
		co_loopback.lag += randf_range(-1, 1) * (co_loopback.lag * 0.2)

	# Adjust target_time_offset periodically to compensate for unstable ping
	
	if co_ticks.ticks % 30 == 0:

		# NOTE: To compensate for latency variation: use the latency median (sliding window algorithm) and use the variation (max) as the padding
		
		co_predict_data.target_time_offset = co_loopback.lag + (1000.0 / physics_fps) * 2
		co_predict_data.tick_offset = ceil(co_predict_data.target_time_offset / (1000.0 / physics_fps))
		
		var target_tick = co_ticks.server_ticks + co_predict_data.tick_offset
		var target_time = curr_time + co_predict_data.target_time_offset

		Log.out(self, "Updating tick offset to %s" % co_predict_data.tick_offset)
		Log.out(self, "target_tick %s | target_time %s | with tick offset %s" % [target_tick, target_time, curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps) ])
		Log.out(self, "target_tick_timestamp %s" % [target_tick * (1000.0 / physics_fps) ])
	
	co_predict_data.target_tick = co_ticks.server_ticks + co_predict_data.tick_offset
	# NOTE: Sumar 1 o no sumar 1 a target_tick?
	
	Log.out(self, "ticks local %s | net %s %s %s" % [co_ticks.ticks, co_ticks.server_ticks, co_predict_data.target_tick, co_ticks.ticks + co_ticks.server_ticks_offset])
