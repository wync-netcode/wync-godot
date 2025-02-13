extends System
class_name SyWyncLerp
const label: StringName = StringName("SyWyncLerp")


func _ready():
	components = [
		CoActor.label,
		CoActorRenderer.label,
		CoFlagWyncEntityTracked.label
	]
	super()
	

func on_process(entities, _data, _delta: float):

	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# TODO: Move this elsewhere
	co_ticks.lerp_delta_accumulator_ms += int(_delta * 1000)
	var curr_tick_time = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, co_ticks.ticks)
	var curr_time = curr_tick_time + co_ticks.lerp_delta_accumulator_ms
	var physics_fps = Engine.physics_ticks_per_second
	var target_time = 0

	#Log.out(self, "%s curr_time %s | %s | %s | %s" % [co_ticks.ticks, curr_time, curr_tick_time + co_ticks.lerp_delta_accumulator_ms, co_ticks.lerp_delta_accumulator_ms, curr_time - (curr_tick_time + co_ticks.lerp_delta_accumulator_ms) ])

	for entity: Entity in entities:
		
		# define target time to render

		target_time = curr_time - co_predict_data.lerp_ms

		var co_actor = entity.get_component(CoActor.label) as CoActor
		if not WyncUtils.is_entity_tracked(wync_ctx, co_actor.id):
			continue
			
		# interpolate props

		for prop_id in wync_ctx.entity_has_props[co_actor.id]:
			var prop = wync_ctx.props[prop_id]
			if prop is not WyncEntityProp:
				continue
			prop = prop as WyncEntityProp
			
			# is prop interpolable (aka numeric, Vector2)
			
			if not prop.interpolated:
				continue
			if prop.data_type not in WyncEntityProp.INTERPOLABLE_DATA_TYPES:
				continue

			# find two snapshots

			# TODO: Separate this cases: first lerp confirmed states, then lerp predicted
			var snap_left = null
			var snap_right = null
			var snap_left_tick: int = 0
			var snap_right_tick: int = 0
			var found_snapshots = false
			var using_confirmed_state = false
			
			if WyncUtils.prop_is_predicted(wync_ctx, prop_id):

				if prop.pred_prev.data != null:
					snap_left_tick = prop.pred_prev.server_tick
					snap_right_tick = prop.pred_curr.server_tick
					snap_left = prop.pred_prev.data
					snap_right = prop.pred_curr.data

					found_snapshots = true
					target_time = curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps)

			# else fall back to using confirmed state
			
			if not found_snapshots:
				target_time = curr_time - co_predict_data.lerp_ms
				var snaps = WyncUtils.find_closest_two_snapshots_from_prop(wync_ctx, target_time, prop, co_ticks, co_predict_data)

				if snaps.size() == 2:
					snap_left_tick = snaps[0]
					snap_right_tick = snaps[1]
					snap_left = prop.confirmed_states.get_at(snap_left_tick)
					snap_right = prop.confirmed_states.get_at(snap_right_tick)

					using_confirmed_state = true
					found_snapshots = true

			if not found_snapshots:
				#Log.out(self, "lerppast NOTFOUND left: %s | target: %s | right: %s | curr: %s" % [0, target_time, 0, curr_time])
				continue

			# interpolate between the two

			var left_timestamp = 0
			var right_timestamp = 0

			if using_confirmed_state:
				# FIXME: two tick datas could have arrive at the same tick
				var left_arrived_at_tick = prop.arrived_at_tick.get_at(snap_left_tick)
				var right_arrived_at_tick = prop.arrived_at_tick.get_at(snap_right_tick)

				left_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, left_arrived_at_tick)
				right_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, right_arrived_at_tick)
				
				# TODO: Make this calculation elsewhere
				co_ticks.last_tick_rendered_left = max(co_ticks.last_tick_rendered_left, snap_left_tick)
				#Log.out(self, "last (right) tick is %d | %d" % [snap_left.arrived_at_tick, snap_right.arrived_at_tick])
			else:
				# TODO: Why a difference of two ticks?
				left_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_left_tick +1, co_ticks, co_predict_data)
				right_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_right_tick +1, co_ticks, co_predict_data)
			
			if abs(left_timestamp - right_timestamp) < 0.000001:
				prop.interpolated_state = snap_right
			else:
				var factor = clampf(
					(float(target_time) - left_timestamp) / (right_timestamp - left_timestamp),
					0, 1)
				
				match prop.data_type:
					WyncEntityProp.DATA_TYPE.FLOAT:
						var left_pos = snap_left as float
						var right_pos = snap_right as float
						prop.interpolated_state = lerp(left_pos, right_pos, factor)
					WyncEntityProp.DATA_TYPE.VECTOR2:
						var left_pos = snap_left as Vector2
						var right_pos = snap_right as Vector2
						prop.interpolated_state = left_pos.lerp(right_pos, factor)
					_:
						Log.out(self, "W: data type not interpolable")
						pass
					
				
				#Log.out(self, "leftardiff %s | left: %s | target: %s | right: %s | factor %s ||| " % [target_time - left_timestamp, left_timestamp, target_time, right_timestamp, factor])
