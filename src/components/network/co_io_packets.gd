extends Component
class_name CoIOPackets
const label = "coiopackets"


## Packet buffers for the network transport to send out and deliver in

var peer_id: int
var in_packets: Array[NetPacket]
var out_packets: Array[NetPacket]
