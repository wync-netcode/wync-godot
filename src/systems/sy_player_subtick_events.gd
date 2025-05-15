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
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_ticks = wync_ctx.co_ticks
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	
	# poll once per tick
	if co_wync_events.last_tick_polled == co_ticks.ticks:
		Log.out("skipping", Log.TAG_SUBTICK_EVENT)
		return
	co_wync_events.last_tick_polled = co_ticks.ticks
	
	# send time warp info: last_tick_rendered_left, lerp_delta_time_ms
	
	var frame_ms = 1000.0 / Engine.physics_ticks_per_second
	#var last_tick_rendered_left = ClockUtils.convert_local_ticks_to_server_ticks(co_ticks, co_ticks.last_tick_rendered_left)
	var last_tick_rendered_left = co_ticks.last_tick_rendered_left
	var lerp_delta: float = co_ticks.lerp_delta_accumulator_ms / frame_ms # range [0.0, 1.0]
	Log.out("SyActorEvents lerp_delta %s | %s | tick_left %s" % [lerp_delta, co_ticks.lerp_delta_accumulator_ms, last_tick_rendered_left], Log.TAG_SUBTICK_EVENT)
	
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
	
	var co_ticks = wync_ctx.co_ticks
	var co_predict_data = wync_ctx.co_predict_data
	
	var curr_tick_time = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, co_ticks.ticks)
	var curr_time = curr_tick_time + co_ticks.lerp_delta_accumulator_ms
	var target_time_conf = curr_time - co_predict_data.lerp_ms
	
	var left_timestamp_ms: int
	var right_timestamp_ms: int
	var left_value: Variant
	var right_value: Variant
	var interpolated_value: Variant
	var prop = WyncUtils.entity_get_prop(wync_ctx, entity_id, "position")


	# NOTE: opportunity to optimize this by not recalculating this each loop

	left_timestamp_ms = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, prop.lerp_left_local_tick)
	right_timestamp_ms = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, prop.lerp_right_local_tick)

	left_value = prop.confirmed_states.get_at(prop.lerp_left_confirmed_state_tick)
	right_value = prop.confirmed_states.get_at(prop.lerp_right_confirmed_state_tick)
	if left_value == null:
		return

	# NOTE: Maybe check for value integrity

	if abs(left_timestamp_ms - right_timestamp_ms) < 0.000001:
		interpolated_value = right_value
	else:
		var factor = clampf(
			(float(target_time_conf) - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms),
			0, 1)

		match prop.data_type:
			WyncEntityProp.DATA_TYPE.FLOAT:
				var left = left_value as float
				var right = right_value as float
				interpolated_value = lerp(left, right, factor)
			WyncEntityProp.DATA_TYPE.VECTOR2:
				var left = left_value as Vector2
				var right = right_value as Vector2
				interpolated_value = lerp(left, right, factor)
			_:
				Log.out("W: data type not interpolable", Log.TAG_SUBTICK_EVENT)
				pass

	DebugPlayerTrail.spawn(node_ctx, interpolated_value, 0.9, 2.5)
