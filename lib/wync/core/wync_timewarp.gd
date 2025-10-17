class_name WyncTimeWarp


# server only
static func prop_set_timewarpable(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	if prop.lerp_enabled: assert(prop.co_lerp.lerp_user_data_type > 0) # avoid accidental default values
	prop.timewarp_enabled = true
	prop.statebff.saved_states = RingBuffer.new(ctx.max_tick_history_timewarp, null)
	prop.statebff.state_id_to_tick = RingBuffer.new(ctx.max_tick_history_timewarp, -1)
	prop.statebff.tick_to_state_id = RingBuffer.new(ctx.max_tick_history_timewarp, -1)
	prop.statebff.state_id_to_local_tick = RingBuffer.new(ctx.max_tick_history_timewarp, -1) # TODO: this is only for lerp
	
	return OK


# server only
static func prop_is_timewarpable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop := WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return false
	return prop.timewarp_enabled
