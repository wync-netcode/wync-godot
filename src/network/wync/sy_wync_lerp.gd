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

	var curr_time = ClockUtils.time_get_ticks_msec(co_ticks)
	var physics_fps = Engine.physics_ticks_per_second
	
	# define target time to render
	var frame = (1000.0 / physics_fps)
	var pkt_inter_arrival_time = ((1000.0 / physics_fps) * 10) # NOTE: This will be important later
	var target_time = curr_time - co_predict_data.lerp_ms


	for entity: Entity in entities:
		
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

			var snap_left: NetTickData = null
			var snap_right: NetTickData = null
			var found_snapshots = false
			var using_confirmed_state = false
			
			if WyncUtils.prop_is_predicted(wync_ctx, prop_id):

				if prop.pred_prev.data != null:
					snap_left = prop.pred_prev
					snap_right = prop.pred_curr
					found_snapshots = true
					target_time = curr_time + co_predict_data.tick_offset * (1000.0 / physics_fps)

			# else fall back to using confirmed state
			
			if not found_snapshots:
				target_time = curr_time - co_predict_data.lerp_ms
				var snaps = WyncUtils.find_closest_two_snapshots_from_prop(target_time, prop)

				if snaps.size() == 2:
					snap_left = snaps[0] as NetTickData
					snap_right = snaps[1] as NetTickData
					using_confirmed_state = true
					found_snapshots = true

			if not found_snapshots:
				#Log.out(self, "lerppast NOTFOUND left: %s | target: %s | right: %s | curr: %s" % [0, target_time, 0, curr_time])
				continue

			# interpolate between the two

			var left_timestamp = 0
			var right_timestamp = 0

			if using_confirmed_state:
				left_timestamp = snap_left.timestamp
				right_timestamp = snap_right.timestamp
			else:
				# TODO: Why a difference of two ticks?
				left_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_left.tick+2, co_ticks, co_predict_data)
				right_timestamp = ClockUtils.get_predicted_tick_local_time_msec(snap_right.tick+2, co_ticks, co_predict_data)
			
			if abs(left_timestamp - right_timestamp) < 0.000001:
				prop.interpolated_state = snap_right.data
			else:
				var factor = clampf(
					(float(target_time) - left_timestamp) / (right_timestamp - left_timestamp),
					0, 1)
				
				match prop.data_type:
					WyncEntityProp.DATA_TYPE.FLOAT:
						var left_pos = snap_left.data as float
						var right_pos = snap_right.data as float
						prop.interpolated_state = lerp(left_pos, right_pos, factor)
					WyncEntityProp.DATA_TYPE.VECTOR2:
						var left_pos = snap_left.data as Vector2
						var right_pos = snap_right.data as Vector2
						prop.interpolated_state = left_pos.lerp(right_pos, factor)
					_:
						Log.out(self, "W: data type not interpolable")
						pass
					
				
				#Log.out(self, "leftardiff %s | left: %s | target: %s | right: %s | factor %s ||| target_time_offset %s" % [target_time - left_timestamp, left_timestamp, target_time, right_timestamp, factor, co_predict_data.target_time_offset])
