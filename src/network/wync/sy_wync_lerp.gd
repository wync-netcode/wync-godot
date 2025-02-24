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
	

func on_process(_entities, _data, _delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_predict_data = wync_ctx.co_predict_data
	var co_ticks = wync_ctx.co_ticks

	# TODO: Move this elsewhere
	co_ticks.lerp_delta_accumulator_ms += int(_delta * 1000)

	interpolate_all(wync_ctx, co_ticks, co_predict_data)


## interpolates confirmed states and predicted states
static func interpolate_all(wync_ctx: WyncCtx, co_ticks: CoTicks, co_predict_data: CoPredictionData):

	var curr_tick_time = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, co_ticks.ticks)
	var curr_time = curr_tick_time + co_ticks.lerp_delta_accumulator_ms
	var target_time_conf = curr_time - co_predict_data.lerp_ms
	var target_time_pred = curr_time

	# then interpolate them 

	var left_timestamp_ms: int
	var right_timestamp_ms: int
	var left_value: Variant
	var right_value: Variant
	var factor: float

	for prop_id: int in range(wync_ctx.props.size()):
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.interpolated:
			continue

		# NOTE: opportunity to optimize this by not recalculating this each loop

		left_timestamp_ms = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, prop.lerp_left_local_tick)
		right_timestamp_ms = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, prop.lerp_right_local_tick)

		if prop.lerp_use_confirmed_state:
			left_value = prop.confirmed_states.get_at(prop.lerp_left_confirmed_state_tick)
			right_value = prop.confirmed_states.get_at(prop.lerp_right_confirmed_state_tick)
		else:
			left_value = prop.pred_prev.data
			right_value = prop.pred_curr.data
		if left_value == null:
			continue

		# NOTE: Maybe check for value integrity

		if abs(left_timestamp_ms - right_timestamp_ms) < 0.000001:
			prop.interpolated_state = right_value
		else:
			if prop.lerp_use_confirmed_state:
				factor = clampf(
				(float(target_time_conf) - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms),
				0, 1)
			else:
				factor = clampf(
				(float(target_time_pred) - left_timestamp_ms) / (right_timestamp_ms - left_timestamp_ms),
				0, 1)
				#Log.out(self, "left %s target %s right %s" % [left_timestamp_ms, target_time_pred, right_timestamp_ms])

			match prop.data_type:
				WyncEntityProp.DATA_TYPE.FLOAT:
					var left = left_value as float
					var right = right_value as float
					prop.interpolated_state = lerp(left, right, factor)
				WyncEntityProp.DATA_TYPE.VECTOR2:
					var left = left_value as Vector2
					var right = right_value as Vector2
					prop.interpolated_state = lerp(left, right, factor)
				_:
					Log.out("Lerp | W: data type not interpolable", Log.TAG_LERP)
					pass


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

		left_value = prop.confirmed_states.get_at(tick_left)
		right_value = prop.confirmed_states.get_at(tick_left +1)
		if left_value == null || right_value == null:
			continue

		var lerped_state = WyncUtils.lerp_any(left_value, right_value, lerp_delta)
		Log.out("EVENT | curr_tick %s, event_tick %s | prop(%s)(%s) lerp_delta %s" % [co_ticks.ticks, tick_left, prop_id, prop.name_id, lerp_delta], Log.TAG_LERP)
		prop.interpolated_state = lerped_state
		prop.setter.call(lerped_state)


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

		var tick_value = prop.confirmed_states.get_at(tick)
		if tick_value == null:
			continue
		prop.setter.call(tick_value)
