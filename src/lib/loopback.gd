class_name Loopback


class Context:
	var peers: Array[IOPeer]  
	## represent packets flying in the network
	var packets: Array[Packet]
	var _latency_mean: int = 200
	var _latency_std_dev: int = 5
	var latency: int = _latency_mean  # (ms)
	var jitter: int = 0  # (ms) how late/early a packet might be
	var packet_loss_percentage: float = 0 # [0-100]
	var time_last_pkt_sent: int = 0
	var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
	var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets

	# Array<peer_from: int, Array<peer_to: int, Array<[0] last_number_sent: int [1] last_number_created> >
	# Array[Array[int]]
	var last_pkt_number_sent_from_peer_to_peer: Array[Array] 

	const simulate_every_ms: int = 10
	var simulation_delta_acumulator: float = 0 # seconds
	var random_generator = RandomNumberGenerator.new()


class IOPeer:
	var peer_id: int
	var in_packets: Array[Packet]
	var out_packets: Array[Packet]


class Packet:
	var data: Variant
	var to_peer: int # destination, peer key
	var from_peer: int = -1 # origin, only the transport can touch this value
	var _deliver_time: int # ms
	var _simulate_ordered_packet_loss: bool = false # for simulating packet drop of RELIABLE packets
	var _reliable: bool = false
	var _reliable_id: int


static func system_fluctuate_latency(ctx: Context):
	# TODO: Make latency polling rate a final user setting
	ctx.latency = int(ctx.random_generator.randfn(ctx._latency_mean, ctx._latency_std_dev))
	ctx.latency = max(0, ctx.latency)


static func system_send_receive(ctx: Context):
	var curr_time = Time.get_ticks_msec()

	# ready to simulate

	#ctx.simulation_delta_acumulator += delta
	#if ctx.simulation_delta_acumulator * 1000 < ctx.simulate_every_ms:
	#	return
	#ctx.simulation_delta_acumulator = 0
		
	# look for pending packets to send

	for io_peer in ctx.peers:
		for pkt: Packet in io_peer.out_packets:
			pkt.from_peer = io_peer.peer_id
			pkt._deliver_time = curr_time + ctx.latency

			if pkt._simulate_ordered_packet_loss:
				# 3 times latency: (1) first send, dropped; (2) confirming what was received;
				# (3) resending it realizing it was dropped.
				# A transport with redundancy would just need 2.
				pkt._deliver_time = curr_time + ctx.latency * 3

			pkt._deliver_time += ctx.jitter * ctx.random_generator.randf_range(-1, 1)
			ctx.packets.append(pkt)

		io_peer.out_packets.clear()

	# look for packets ready to be received

	var ids_to_delete: Array[int] = []

	for k in range(ctx.packets.size()):
		var pkt = ctx.packets[k] as Packet
		if curr_time < pkt._deliver_time:
			continue

		# check for reliability before sending
		if pkt._reliable:
			var last_pkt_ids: Array[int] = ctx.last_pkt_number_sent_from_peer_to_peer[pkt.from_peer][pkt.to_peer]
			if last_pkt_ids[0] != pkt._reliable_id:
				continue

			# else, deliver and increase last_sent
			last_pkt_ids[0] += 1

		ids_to_delete.append(k)

		# get destination buffer from registered peers

		var peer: IOPeer = ctx.peers[pkt.to_peer]
		if not peer:
			print("E: Couldn't find peer %s" % [pkt.to_peer])
			continue

		# deliver

		peer.in_packets.append(pkt)
	
	# remove from right to left
	for i: int in range(ids_to_delete.size()-1, -1, -1):
		var k = ids_to_delete[i]
		ctx.packets.remove_at(k)


#static func system_caotic_latency(ctx: Context):

	#if Engine.get_physics_frames() % int(Engine.physics_ticks_per_second/2) == 0:
		#ctx._latency_mean += 1
		#if ctx._latency_mean > 600:
			#ctx._latency_mean = 0


static func register_io_peer(ctx: Context, io_peer: IOPeer):

	var new_peer_id = ctx.peers.size()
	var peers_amount = new_peer_id + 1
	io_peer.peer_id = new_peer_id
	ctx.peers.append(io_peer)

	# new entry
	ctx.last_pkt_number_sent_from_peer_to_peer.resize(peers_amount)
	ctx.last_pkt_number_sent_from_peer_to_peer[new_peer_id] = [] as Array[Array]
	ctx.last_pkt_number_sent_from_peer_to_peer[new_peer_id].resize(peers_amount)
	for i: int in range(peers_amount):
		ctx.last_pkt_number_sent_from_peer_to_peer[new_peer_id][i] = [0, 0] as Array[int]

	# update previous
	for i: int in range(peers_amount -1):
		ctx.last_pkt_number_sent_from_peer_to_peer[i].resize(peers_amount)
		ctx.last_pkt_number_sent_from_peer_to_peer[i][new_peer_id] = [0, 0] as Array[int]


static func queue_reliable_packet(ctx: Context, io_peer: IOPeer, to_peer: int, data: Variant):
	var pkt := Packet.new()
	pkt.data = data
	pkt.from_peer = io_peer.peer_id
	pkt.to_peer = to_peer
	pkt._reliable = true
	# pkt.deliver_time = it's defined later, not here

	# simulate packet drop of RELIABLE packet
	if (ctx.packet_loss_percentage > 0 &&
		ctx.random_generator.randf() <= (ctx.packet_loss_percentage / 100.0)):
		pkt._simulate_ordered_packet_loss = true

	var last_pkt_ids: Array[int] = ctx.last_pkt_number_sent_from_peer_to_peer[pkt.from_peer][pkt.to_peer]
	pkt._reliable_id = last_pkt_ids[1]
	last_pkt_ids[1] += 1

	io_peer.out_packets.append(pkt)


static func queue_unreliable_packet(ctx: Context, io_peer: IOPeer, to_peer: int, data: Variant):
	var pkt := Packet.new()
	pkt.data = data
	pkt.from_peer = io_peer.peer_id
	pkt.to_peer = to_peer
	pkt._reliable = false
	# packet.deliver_time = it's defined later, not here

	# simulate packet drop of UNRELIABLE packet
	if (ctx.packet_loss_percentage > 0 &&
		ctx.random_generator.randf() <= (ctx.packet_loss_percentage / 100.0)):
		return

	io_peer.out_packets.append(pkt)
