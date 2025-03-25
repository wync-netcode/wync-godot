extends System
class_name SyNetPredictionTicks
const label: StringName = StringName("SyNetPredictionTicks")

## * Advances the local game tick and the predicted game tick
## NOTE: What if we have different send rates for different entities as a LOD measure?
	

static func wync_update_prediction_ticks (ctx: WyncCtx):
	
	var lat_info := ctx.peer_latency_info[WyncCtx.SERVER_PEER_ID]
	var co_predict_data := ctx.co_predict_data
	var co_ticks := ctx.co_ticks
	
	var curr_time = WyncUtils.clock_get_ms(ctx)
	var physics_fps = Engine.physics_ticks_per_second

	# Adjust tick_offset_desired periodically to compensate for unstable ping
	
	if WyncUtils.fast_modulus(co_ticks.ticks, 32) == 0:

		co_predict_data.tick_offset_desired = ceil(lat_info.latency_stable_ms / (1000.0 / physics_fps)) + 2
		
		var target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
		var target_time = curr_time + co_predict_data.tick_offset_desired * (1000.0 / physics_fps)

		Log.out("co_predict_data.tick_offset_desired %s" % [co_predict_data.tick_offset_desired], Log.TAG_PRED_TICK)
		Log.out("Updating tick offset to %s" % co_predict_data.tick_offset, Log.TAG_PRED_TICK)
		Log.out("target_tick %s | target_time %s | with tick offset %s" % [target_tick, target_time, curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps) ], Log.TAG_PRED_TICK)
		Log.out("target_tick_timestamp %s" % [target_tick * (1000.0 / physics_fps) ], Log.TAG_PRED_TICK)

			
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

	# target_tick can only go forward. Use max so that we never go back
	var _prev_target_tick = co_predict_data.target_tick
	co_predict_data.target_tick = max(co_ticks.server_ticks + co_predict_data.tick_offset, co_predict_data.target_tick)
	co_predict_data.current_tick_timestamp = curr_time

	if (co_predict_data.target_tick - _prev_target_tick != 1):
		Log.outc(ctx, "couldn't find input | target tick changed badly %s %s" % [_prev_target_tick, co_predict_data.target_tick])

	#Log.outc(ctx, "prev_target_tick %s, new_target_tick %s" % [_prev_target_tick, co_predict_data.target_tick])
	
	#Log.out(self, "ticks local %s | net %s %s %s" % [co_ticks.ticks, co_ticks.server_ticks, co_predict_data.target_tick, co_ticks.ticks + co_ticks.server_ticks_offset])
	
	# ==============================================================
	# Setup the next tick-action-history
	# Run before any prediction takes places on the current tick
	# NOTE: This could be moved elsewhere
	
	WyncEventUtils.action_tick_history_reset(ctx, co_predict_data.target_tick)
