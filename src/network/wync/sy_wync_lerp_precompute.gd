extends System
class_name SyWyncLerpPrecompute
const label: StringName = StringName("SyWyncLerpPrecompute")

## Run each logic tick to precompute interpolation variables
## See also 'SyWyncLerp'


func _ready():
	components = [
		CoActor.label,
		CoActorRenderer.label,
		CoFlagWyncEntityTracked.label
	]
	super()
	

func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var co_ticks = wync_ctx.co_ticks

	var curr_tick_time = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, co_ticks.ticks)
	var curr_time = curr_tick_time + int(1000.0 / (Engine.physics_ticks_per_second * 2)) # half a physic frame
	var target_time_conf = curr_time - co_predict_data.lerp_ms

	# precompute which ticks we'll be interpolating

	for prop_id: int in range(wync_ctx.props.size()):
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.interpolated:
			continue

		# -> for predictes states

		if WyncUtils.prop_is_predicted(wync_ctx, prop_id):
			precompute_lerping_prop_predicted(wync_ctx, prop_id, co_ticks)

		# -> for confirmed states
		else:
			precompute_lerping_prop_confirmed_states(wync_ctx, prop_id, target_time_conf, co_ticks, co_predict_data)


func precompute_lerping_prop_confirmed_states(
		wync_ctx: WyncCtx, prop_id: int, target_time: int,
		co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData
	):
	var prop = WyncUtils.get_prop(wync_ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	var snaps = WyncUtils.find_closest_two_snapshots_from_prop(wync_ctx, target_time, prop, co_ticks, co_predict_data)
	if snaps.size() != 2:
		return

	prop.lerp_use_confirmed_state = true
	prop.lerp_left_confirmed_state_tick = snaps[0]
	prop.lerp_right_confirmed_state_tick = snaps[1]
	prop.lerp_left_local_tick = prop.arrived_at_tick.get_at(prop.lerp_left_confirmed_state_tick)
	prop.lerp_right_local_tick = prop.arrived_at_tick.get_at(prop.lerp_right_confirmed_state_tick)

	# TODO: Move this elsewhere
	# NOTE: might want to limit how much it grows
	co_ticks.last_tick_rendered_left = max(co_ticks.last_tick_rendered_left, prop.lerp_left_confirmed_state_tick)


func precompute_lerping_prop_predicted(
		wync_ctx: WyncCtx, prop_id: int,
		co_ticks: CoTicks
	):
	var prop = WyncUtils.get_prop(wync_ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	prop.lerp_use_confirmed_state = false
	prop.lerp_left_local_tick = co_ticks.ticks
	prop.lerp_right_local_tick = co_ticks.ticks +1
