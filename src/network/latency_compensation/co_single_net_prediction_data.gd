extends Component
class_name CoSingleNetPredictionData
static var label = ECS.add_component()
# TODO: Pick a better class name

var last_tick_confirmed: int = 0
var last_tick_timestamp: int = 0

# TODO: Have a standalone system that calculates target_time / target_tick
var target_tick: int = 0
var tick_offset: int = 0
