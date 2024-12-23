extends Component
class_name CoTransportLoopback
static var label = ECS.add_component()

## registered peers
var peers: Array[LoopbackPeer]  
## represent packets flying in the network
var packets: Array[LoopbackPacket]
var _latency_mean: int = 500
var _latency_std_dev: int = 5
var latency: int = _latency_mean  # (ms)
var jitter: int = 0  # (ms) how late/early a packet might be
var packet_loss_percentage: int = 0 # [0-100]
var time_last_pkt_sent: int = 0
var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets

const simulate_every_ms: int = 10
var simulation_delta_acumulator: float = 0
var random_generator = RandomNumberGenerator.new()


func _physics_process(_delta: float) -> void:
	
	# TODO: Make latency polling rate a final user setting
	if Engine.get_physics_frames() % (Engine.physics_ticks_per_second/2) == 0:
		latency = random_generator.randfn(_latency_mean, _latency_std_dev)

	#latency -= 100 * delta; if latency < 0: latency = 1100
	#latency += 100 * delta; if latency > 1100: latency = 0
