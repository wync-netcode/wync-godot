class_name CoTicksUtils


static func init_co_prediction_data(co_pred: WyncCtx.CoPredictionData) -> void:
	co_pred.clock_offset_sliding_window = RingBuffer.new(co_pred.clock_offset_sliding_window_size, 0)


static func init_co_ticks(co_ticks: WyncCtx.CoTicks):
	co_ticks.server_tick_offset_collection.resize(WyncCtx.SERVER_TICK_OFFSET_COLLECTION_SIZE)
	for i: int in range(WyncCtx.SERVER_TICK_OFFSET_COLLECTION_SIZE):
		var tuple = [0, 0]
		co_ticks.server_tick_offset_collection[i] = tuple


static func server_tick_offset_collection_add_value(co_ticks: WyncCtx.CoTicks, new_value: int):
	if server_tick_offset_collection_value_exists(co_ticks, new_value):
		server_tick_offset_collection_increase_value(co_ticks, new_value)
	else:
		var less_common_value = server_tick_offset_collection_get_less_common(co_ticks)
		server_tick_offset_collection_replace_value(co_ticks, less_common_value, new_value)


static func server_tick_offset_collection_replace_value(co_ticks: WyncCtx.CoTicks, find_value: int, new_value: int):
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == find_value:
			tuple[0] = new_value
			tuple[1] = 1
			return


static func server_tick_offset_collection_increase_value(co_ticks: WyncCtx.CoTicks, find_value: int):
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == find_value:
			tuple[1] += 1
			return


static func server_tick_offset_collection_value_exists(co_ticks: WyncCtx.CoTicks, ar_value: int) -> bool:
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == ar_value:
			return true
	return false


static func server_tick_offset_collection_get_most_common(co_ticks: WyncCtx.CoTicks) -> int:
	var highest_count = 0
	var current_value = 0
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[1] > highest_count:
			highest_count = tuple[1]
			current_value = tuple[0]
	return current_value


static func server_tick_offset_collection_get_less_common(co_ticks: WyncCtx.CoTicks) -> int:
	var lowest_count = -1
	var current_value = 0
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[1] < lowest_count || lowest_count == -1:
			lowest_count = tuple[1]
			current_value = tuple[0]
	return current_value
