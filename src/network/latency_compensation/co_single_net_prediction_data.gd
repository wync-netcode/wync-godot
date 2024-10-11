extends Component
class_name CoSingleNetPredictionData
static var label = ECS.add_component()
# TODO: Pick a better class name

#var pkt_inter_arrival_time: int
var last_tick_confirmed: int = 0
var last_tick_timestamp: int = 0
