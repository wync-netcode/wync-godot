extends System
class_name SyNetPredictionTicks
const label: StringName = StringName("SyNetPredictionTicks")

## * Advances the local game tick and the predicted game tick
## NOTE: What if we have different send rates for different entities as a LOD measure?
	

func on_process(_entities, _data, _delta: float):

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	
	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second

	# Adjust tick_offset_desired periodically to compensate for unstable ping
	
	if co_ticks.ticks % 30 == 0:

		co_predict_data.tick_offset_desired = ceil(co_predict_data.latency_stable / (1000.0 / physics_fps)) + 2
		
		var target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
		var target_time = curr_time + co_predict_data.tick_offset_desired * (1000.0 / physics_fps)

		Log.out(self, "co_predict_data.tick_offset_desired %s" % [co_predict_data.tick_offset_desired])
		Log.out(self, "Updating tick offset to %s" % co_predict_data.tick_offset)
		Log.out(self, "target_tick %s | target_time %s | with tick offset %s" % [target_tick, target_time, curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps) ])
		Log.out(self, "target_tick_timestamp %s" % [target_tick * (1000.0 / physics_fps) ])

			
	# Smoothly transition tick_offset
	# NOTE: Should be configurable
	
	if co_predict_data.tick_offset_desired != co_predict_data.tick_offset:
		
		# up transition
		if co_predict_data.tick_offset_desired > co_predict_data.tick_offset:
			co_predict_data.tick_offset += 1
		# down transition
		else:
			if co_predict_data.tick_offset == co_predict_data.tick_offset_prev:
				co_predict_data.tick_offset -= 1
			else:
				# NOTE: Somehow I can't find another way to keep the prev updated
				co_predict_data.tick_offset_prev = co_predict_data.tick_offset

	# use max so that we never go back
	co_predict_data.target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
	co_predict_data.current_tick_timestamp = curr_time
	
	#Log.out(self, "ticks local %s | net %s %s %s" % [co_ticks.ticks, co_ticks.server_ticks, co_predict_data.target_tick, co_ticks.ticks + co_ticks.server_ticks_offset])
	
	# ==============================================================
	# Setup the next tick-action-history
	# Run before any prediction takes places on the current tick
	# NOTE: This could be moved elsewhere
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	WyncEventUtils.action_tick_history_reset(wync_ctx, co_predict_data.target_tick)
