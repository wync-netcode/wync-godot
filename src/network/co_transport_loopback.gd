extends Component
class_name CoTransportLoopback
const label = "cotransportloopback"

## registered peers
var peers: Array[LoopbackPeer]  
## represent packets flying in the network
var packets: Array[LoopbackPacket]
var lag: int = 1500  # (ms)
var jitter: int = 0  # (ms) how late/early a packet might be
var packet_loss_percentage: int = 0 # [0-100]
var time_last_pkt_sent: int = 0
var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets
