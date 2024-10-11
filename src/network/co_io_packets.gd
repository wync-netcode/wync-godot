extends Component
class_name CoIOPackets
static var label = ECS.add_component()


## Packet buffers for the network transport to send out and deliver in

var peer_id: int
var in_packets: Array[NetPacket]
var out_packets: Array[NetPacket]
