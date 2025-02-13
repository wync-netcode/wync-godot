extends System
class_name SyPlayerSubtickEvents
const label: StringName = StringName("SyPlayerSubtickEvents")

func _ready():
	components = [
		CoActorInput.label,
		CoPlayerInput.label,
		CoWyncEvents.label,
	]
	super()


func on_process_entity(entity: Entity, _data, _delta: float):
	var input = entity.get_component(CoActorInput.label) as CoActorInput
	
	# subtick shooting event
	if !input.shoot:
		return
	
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	
	# poll once per tick
	if co_wync_events.last_tick_polled == co_ticks.ticks:
		Log.out(self, "skipping")
		return
	co_wync_events.last_tick_polled = co_ticks.ticks
		
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# send time warp info: last_tick_rendered_left, lerp_delta_time_ms
	
	var frame_ms = 1000.0 / Engine.physics_ticks_per_second
	#var last_tick_rendered_left = ClockUtils.convert_local_ticks_to_server_ticks(co_ticks, co_ticks.last_tick_rendered_left)
	var last_tick_rendered_left = co_ticks.last_tick_rendered_left
	var lerp_delta: float = co_ticks.lerp_delta_accumulator_ms / frame_ms # range [0.0, 1.0]
	Log.out(self, "SyActorEvents lerp_delta %s | %s | tick_left %s" % [lerp_delta, co_ticks.lerp_delta_accumulator_ms, last_tick_rendered_left])
	
	var event_id = WyncEventUtils.instantiate_new_event(wync_ctx, GameInfo.EVENT_PLAYER_SHOOT, 2)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 0, WyncEntityProp.DATA_TYPE.INT, last_tick_rendered_left)
	WyncEventUtils.event_add_arg(wync_ctx, event_id, 1, WyncEntityProp.DATA_TYPE.FLOAT, lerp_delta)
	event_id = WyncEventUtils.event_wrap_up(wync_ctx, event_id)
	
	co_wync_events.events.append(event_id)
	
	# NOTE: See SyPlayerInput for event.clear()
	#co_wync_events.events.clear() Where to clear ?????
	
	debug_show_timewarpable_lerped_positions(self, wync_ctx, 1)


static func debug_show_timewarpable_lerped_positions(node_ctx: Node, wync_ctx: WyncCtx, entity_id: int):

	# TODO: generalize with 'wync_lerp'
	
	var co_ticks = ECS.get_singleton_component(node_ctx, CoTicks.label) as CoTicks
	var co_predict_data = ECS.get_singleton_component(node_ctx, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	
	var curr_tick_time = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, co_ticks.ticks)
	var curr_time = curr_tick_time + co_ticks.lerp_delta_accumulator_ms
	
	var snap_left_tick: int = 0
	var snap_right_tick: int = 0
	var snap_left: Variant = null
	var snap_right: Variant = null
	var prop = WyncUtils.entity_get_prop(wync_ctx, entity_id, "position")
	var target_time = curr_time - co_predict_data.lerp_ms
	var snaps = WyncUtils.find_closest_two_snapshots_from_prop(wync_ctx, target_time, prop, co_ticks, co_predict_data)

	if snaps.size() == 2:
		snap_left_tick = snaps[0]
		snap_right_tick = snaps[1]
		snap_left = prop.confirmed_states.get_at(snap_left_tick)
		snap_right = prop.confirmed_states.get_at(snap_right_tick)
	else:
		return
	
	var left_arrived_at_tick = prop.arrived_at_tick.get_at(snap_left_tick)
	var right_arrived_at_tick = prop.arrived_at_tick.get_at(snap_right_tick)

	var left_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, left_arrived_at_tick)
	var right_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, right_arrived_at_tick)
	var interpolated_state = Vector2.ZERO

	if abs(left_timestamp - right_timestamp) < 0.000001:
		interpolated_state = snap_right
	else:
		var factor = clampf(
			(float(target_time) - left_timestamp) / (right_timestamp - left_timestamp),
			0, 1)
		
		match prop.data_type:
			WyncEntityProp.DATA_TYPE.FLOAT:
				var left_pos = snap_left as float
				var right_pos = snap_right as float
				interpolated_state = lerp(left_pos, right_pos, factor)
			WyncEntityProp.DATA_TYPE.VECTOR2:
				var left_pos = snap_left as Vector2
				var right_pos = snap_right as Vector2
				interpolated_state = left_pos.lerp(right_pos, factor)
			_:
				Log.out(node_ctx, "W: data type not interpolable")
				pass
	
	var last_tick_rendered_left = snap_left_tick
	Log.out(node_ctx, "EVENT | snap_left_tick local:%s | converted:%s" % [ snap_left_tick, last_tick_rendered_left ])
	DebugPlayerTrail.spawn(node_ctx, interpolated_state, 0.9, 2.5)
