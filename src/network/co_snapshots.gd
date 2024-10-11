extends Component
class_name CoSnapshots
static var label = ECS.add_component()

## Map[entity_id: int, position_snapshots: Array<4>[PositionSnapshot]]
## or Dictionary[int, RingBuffer[PositionSnapshot]]
var entity_snapshots: Dictionary 

# NOTE: This could be moved to it's own component

#var amount_pkts_received: int
#var sum_pkt_inter_arrival_time: int

## (ms) time last packet was received
var time_last_pkt_received: int

## (ms) time between consecutive packets, used in interpolation
var pkt_inter_arrival_time: float

## (ms) this padding could be calculated depending on mean_pkt_inter_arrival_time variation / deviation
# TODO: var interpolation_padding: int

