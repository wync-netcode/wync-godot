extends System
class_name SyWyncLerp
const label: StringName = StringName("SyWyncLerp")

## Runs each draw loop; interpolates confirmed state and predicted state
## See also 'SyWyncLerpPrecompute'


func _ready():
	components = [
		CoActor.label,
		CoActorRenderer.label,
		CoFlagWyncEntityTracked.label
	]
	super()
	

func on_process(_entities, _data, delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# TODO: Move this elsewhere

	WyncWrapper.wync_interpolate_all(wync_ctx, delta)


## timewarp, server only
## @argument tick_left: int. Base tick to restore state from
static func confirmed_states_set_to_tick_interpolated (
	wync_ctx: WyncCtx, prop_ids: Array[int], tick_left: int, lerp_delta: float,
	co_ticks: CoTicks
	):

	if (tick_left >= co_ticks.ticks):
		return

	# then interpolate them 

	var left_value: Variant
	var right_value: Variant

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp

		left_value = WyncEntityProp.saved_state_get(prop, tick_left)
		right_value = WyncEntityProp.saved_state_get(prop, tick_left +1)
		if left_value == null || right_value == null:
			continue

		var lerped_state = WyncUtils.lerp_any(left_value, right_value, lerp_delta)
		Log.out("EVENT | curr_tick %s, event_tick %s | prop(%s)(%s) lerp_delta %s" % [co_ticks.ticks, tick_left, prop_id, prop.name_id, lerp_delta], Log.TAG_LERP)
		prop.interpolated_state = lerped_state
		prop.setter.call(prop.user_ctx_pointer, lerped_state)


static func confirmed_states_set_to_tick (
	wync_ctx: WyncCtx, prop_ids: Array[int], tick: int,
	co_ticks: CoTicks
	):

	if (tick > co_ticks.ticks):
		return

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp

		var tick_value = WyncEntityProp.saved_state_get(prop, tick)
		if tick_value == null:
			continue

		prop.setter.call(prop.user_ctx_pointer, tick_value)
