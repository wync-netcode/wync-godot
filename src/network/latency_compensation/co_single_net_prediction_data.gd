extends Component
class_name CoSingleNetPredictionData
static var label = ECS.add_component()
# TODO: Pick a better class name

# periodical vars

var tick_offset: int = 0
var target_tick: int = 0 # co_ticks.ticks + tick_offset
var target_time_offset: int = 0 # add this to curr_time to get the actual target_time

# For calculating clock_offset_median

var clock_packets_received: int
var clock_offset_median: float
var clock_offset_accumulator: int
