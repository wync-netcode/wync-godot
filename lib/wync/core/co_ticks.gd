class_name CoTicks

# for "debug_tick_offset" just set ctx.co_ticks.ticks to any value
var debug_time_offset_ms: int

var ticks: int
var server_ticks: int

## Strategy for getting a stable server_tick_offset value:
## We have a list of of common values and their count
## value | percentage
## -199  | 212
## -201  | 98
## -202  | 13
## Then we just pick the most common one, if we encounter
## a new value just replace the one with less count. Also, there shouldn't
## be fight between two adyacent values (e.g. -199 & -200) because the
## code for picking a value prevents fluctuation of one unit

## List<Tuple<int, int>>
## Array[Array[Variant]]
var server_tick_offset_collection: Array[Array]
var server_tick_offset: int
const SERVER_TICK_OFFSET_COLLECTION_SIZE := 4

# TODO: Move this elsewhere
# used to (1) lerp and (2) time warp
var lerp_delta_accumulator_ms: float
var last_tick_rendered_left: int
var minimum_lerp_fraction_accumulated_ms: float


func _init():
	server_tick_offset_collection.resize(SERVER_TICK_OFFSET_COLLECTION_SIZE)
	for i: int in range(SERVER_TICK_OFFSET_COLLECTION_SIZE):
		var tuple = [0, 0]
		server_tick_offset_collection[i] = tuple


static func server_tick_offset_collection_add_value(co_ticks: CoTicks, new_value: int):
	if server_tick_offset_collection_value_exists(co_ticks, new_value):
		server_tick_offset_collection_increase_value(co_ticks, new_value)
	else:
		var less_common_value = server_tick_offset_collection_get_less_common(co_ticks)
		server_tick_offset_collection_replace_value(co_ticks, less_common_value, new_value)


static func server_tick_offset_collection_replace_value(co_ticks: CoTicks, find_value: int, new_value: int):
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == find_value:
			tuple[0] = new_value
			tuple[1] = 1
			return


static func server_tick_offset_collection_increase_value(co_ticks: CoTicks, find_value: int):
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == find_value:
			tuple[1] += 1
			return


static func server_tick_offset_collection_value_exists(co_ticks: CoTicks, ar_value: int) -> bool:
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[0] == ar_value:
			return true
	return false


static func server_tick_offset_collection_get_most_common(co_ticks: CoTicks) -> int:
	var highest_count = 0
	var current_value = 0
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[1] > highest_count:
			highest_count = tuple[1]
			current_value = tuple[0]
	return current_value


static func server_tick_offset_collection_get_less_common(co_ticks: CoTicks) -> int:
	var lowest_count = -1
	var current_value = 0
	for tuple: Array in co_ticks.server_tick_offset_collection:
		if tuple[1] < lowest_count || lowest_count == -1:
			lowest_count = tuple[1]
			current_value = tuple[0]
	return current_value
