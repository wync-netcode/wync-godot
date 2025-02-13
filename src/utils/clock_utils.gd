class_name ClockUtils


# NOTE: Maybe rename to get_local_time_msec
static func time_get_ticks_msec(co_ticks: CoTicks) -> int:
	return Time.get_ticks_msec() + co_ticks.time_ms_offset


# NOTE: Maybe rename to get_server_tick_local_time_msec
static func get_predicted_tick_local_time_msec(ticks: int, co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData) -> int:
	var frame = 1000.0 / Engine.physics_ticks_per_second
	var tick_diff = ticks - co_ticks.server_ticks
	return co_predict_data.current_tick_timestamp + tick_diff * frame


"""
static func local_time_to_server_time(co_predict_data: CoSingleNetPredictionData, local_time: int) -> int:
	return local_time + co_predict_data.clock_offset_mean


static func server_time_to_local_time(co_predict_data: CoSingleNetPredictionData, server_time: int) -> int:
	return server_time - co_predict_data.clock_offset_mean

static func get_net_ticks(co_ticks: CoTicks) -> int:
	return co_ticks.ticks + co_ticks.server_ticks_offset
"""

static func convert_local_ticks_to_server_ticks(co_ticks: CoTicks, ticks: int) -> int:
	return ticks + co_ticks.server_ticks_offset


#static func convert_server_ticks_to_local_ticks(co_ticks: CoTicks, ticks: int) -> int:
	#return ticks - co_ticks.server_ticks_offset


static func get_tick_local_time_msec(co_predict_data: CoSingleNetPredictionData, co_ticks: CoTicks, ticks: int):
	var frame = 1000.0 / Engine.physics_ticks_per_second
	return co_predict_data.current_tick_timestamp + (ticks - co_ticks.ticks) * frame
