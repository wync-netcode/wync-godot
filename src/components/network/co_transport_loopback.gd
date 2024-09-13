extends Component
class_name CoTransportLoopback
const label = "cotransportloopback"

var peers: Array[LoopbackPeer]  # registered peers
var packets: Array[LoopbackPacket]  # represent packets flying in the network
var lag: int = 500  # (ms)
var jitter: int = 0  # (ms) how many frames a package might be late
var packet_loss_percentage: int = 0 # [0-100]
var time_last_pkt_sent: int = 0
var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets
