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
	var ctx = single_wync.ctx as WyncCtx
	wync_lerp_precompute (ctx)


static func wync_lerp_precompute (ctx: WyncCtx):
	var co_predict_data = ctx.co_predict_data
	var co_ticks = ctx.co_ticks

	var curr_tick_time = WyncUtils.clock_get_tick_timestamp_ms(ctx, co_ticks.ticks)
	var curr_time = curr_tick_time + int(1000.0 / (Engine.physics_ticks_per_second * 2)) # half a physic frame
	var target_time_conf = curr_time - co_predict_data.lerp_ms

	# precompute which ticks we'll be interpolating
	# TODO: might want to use another filtered prop list for 'predicted'.
	# Before doing that we might need to settled on our strategy for extrapolation as fallback
	# of interpolation for confirmed states

	for prop_id in ctx.type_state__interpolated_regular_prop_ids:

		# -> for predictes states

		if WyncUtils.prop_is_predicted(ctx, prop_id):
			precompute_lerping_prop_predicted(ctx, prop_id, co_ticks)

		# -> for confirmed states
		else:
			precompute_lerping_prop_confirmed_states(ctx, prop_id, target_time_conf)


static func precompute_lerping_prop_confirmed_states(
		ctx: WyncCtx, prop_id: int, target_time: int
	):
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	var snaps = WyncUtils.find_closest_two_snapshots_from_prop(ctx, target_time, prop)
	if snaps[0] == -1:
		return

	if (prop.lerp_left_confirmed_state_tick == snaps[0] &&
		prop.lerp_right_confirmed_state_tick == snaps[1]):
		return

	prop.lerp_use_confirmed_state = true
	prop.lerp_left_confirmed_state_tick = snaps[0]
	prop.lerp_right_confirmed_state_tick = snaps[1]
	prop.lerp_left_local_tick = snaps[2]
	prop.lerp_right_local_tick = snaps[3]

	# TODO: Move this elsewhere
	# NOTE: might want to limit how much it grows
	ctx.co_ticks.last_tick_rendered_left = max(ctx.co_ticks.last_tick_rendered_left, prop.lerp_left_confirmed_state_tick)

	var val_left = WyncEntityProp.saved_state_get_throughout(prop, prop.lerp_left_confirmed_state_tick)
	var val_right = WyncEntityProp.saved_state_get_throughout(prop, prop.lerp_right_confirmed_state_tick)

	prop.lerp_left_state = val_left
	prop.lerp_right_state = val_right

	Log.outc(ctx, "deblerp, precomp | l(%s,%s) s(%s,%s) v(%.3f,%.3f)" % [
		snaps[2], snaps[3], snaps[0], snaps[1], val_left.x, val_right.x ])


static func precompute_lerping_prop_predicted(
		ctx: WyncCtx, prop_id: int,
		co_ticks: CoTicks
	):
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return
	prop = prop as WyncEntityProp

	prop.lerp_use_confirmed_state = false
	prop.lerp_left_local_tick = co_ticks.ticks
	prop.lerp_right_local_tick = co_ticks.ticks +1
