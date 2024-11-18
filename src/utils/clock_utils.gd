class_name ClockUtils


static func time_get_ticks_msec(co_ticks: CoTicks) -> int:
	return Time.get_ticks_msec() + co_ticks.time_ms_offset


static func get_server_time(co_predict_data: CoSingleNetPredictionData, local_time: int) -> int:
	return local_time + co_predict_data.clock_offset_median


static func get_net_ticks(co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData):
	return co_ticks.ticks - co_ticks.server_ticks_offset
