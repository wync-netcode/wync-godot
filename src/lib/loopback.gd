class_name Loopback


class Context:
	var peers: Array[IOPeer]  
	## represent packets flying in the network
	var packets: Array[Packet]
	var _latency_mean: int = 500
	var _latency_std_dev: int = 5
	var latency: int = _latency_mean  # (ms)
	var jitter: int = 0  # (ms) how late/early a packet might be
	var packet_loss_percentage: int = 0 # [0-100]
	var time_last_pkt_sent: int = 0
	var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
	var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets

	const simulate_every_ms: int = 10
	var simulation_delta_acumulator: float = 0 # seconds
	var random_generator = RandomNumberGenerator.new()


class IOPeer:
	var peer_id: int
	var in_packets: Array[Packet]
	var out_packets: Array[Packet]


class Packet:
	var data: Variant
	var deliver_time: int # ms
	var to_peer: int # destination, peer key
	var from_peer: int = -1 # origin, only the transport can touch this value


static func system_fluctuate_latency(ctx: Context):
	# TODO: Make latency polling rate a final user setting
	ctx.latency = int(ctx.random_generator.randfn(ctx._latency_mean, ctx._latency_std_dev))
	ctx.latency = max(0, ctx.latency)


static func system_send_receive(ctx: Context, io_peer: IOPeer, delta: float):
	var curr_time = Time.get_ticks_msec()

	# ready to simulate

	ctx.simulation_delta_acumulator += delta
	
	if ctx.simulation_delta_acumulator * 1000 < ctx.simulate_every_ms:
		return

	ctx.simulation_delta_acumulator = 0
		
	# look for pending packets to send

	for pkt: Packet in io_peer.out_packets:
		pkt.from_peer = io_peer.peer_id
		pkt.deliver_time = curr_time + ctx.latency
		ctx.packets.append(pkt)

	io_peer.out_packets.clear()

	# look for packets ready to be received

	for k in range(ctx.packets.size()-1, -1, -1):
		var pkt = ctx.packets[k] as Packet
		if curr_time < pkt.deliver_time:
			continue
			
		# consume
		ctx.packets.remove_at(k)

		# get destination buffer from registered peers

		var peer: IOPeer = ctx.peers[pkt.to_peer]
		if not peer:
			print("E: Couldn't find peer %s" % [pkt.to_peer])
			continue

		# deliver

		peer.in_packets.append(pkt)


static func system_caotic_latency(ctx: Context):

	if Engine.get_physics_frames() % int(Engine.physics_ticks_per_second/2) == 0:
		ctx._latency_mean += 1
		if ctx._latency_mean > 600:
			ctx._latency_mean = 0


static func register_io_peer(ctx: Context, io_peer: IOPeer):

	io_peer.peer_id = ctx.peers.size()
	ctx.peers.append(io_peer)


static func queue_packet(io_peer: IOPeer, to_peer: int, data: Variant):
	var packet := Packet.new()
	packet.data = data
	packet.from_peer = io_peer.peer_id
	packet.to_peer = to_peer
	# packet.deliver_time = defined later
	io_peer.out_packets.append(packet)
