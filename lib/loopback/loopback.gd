class_name Loopback

## Simulates a Server, Client(s) topology

class Context:
	var peers: Array[IOPeer]  
	var packets: Array[Packet] # flying packets
	# Array<peer_from: int, Array<peer_to: int, Array<[0] last_number_sent: int [1] last_number_created> >
	# Array[Array[int]]
	var last_pkt_number_sent_from_peer_to_peer: Array[Array] 
	var random_generator = RandomNumberGenerator.new()

	#var jitter: int = 0  # (ms) how late/early a packet might be # Superseeded by std_dev??
	#var jitter_unordered_packets: bool = false # Allows jitter to mangle packet order
	#var duplicated_packets_percentage: int = 0 # [0-100] Allows duplicated packets # TODO


class IOPeer:
	var peer_id: int
	var in_packets: Array[Packet]
	var out_packets: Array[Packet]
	var disabled: bool ## for debugging purposes, can emulate a temporal disconnection

	var latency_current_ms: int
	var latency_mean_ms: int
	var latency_std_dev_ms: int
	var packet_loss_percentage: int ## [0-100] inclusive
	var packet_duplicate_percentage: int ## [0-100] inclusive


class Packet:
	var data: Variant
	var to_peer: int # destination, peer key
	var from_peer: int = -1 # origin, only the transport can touch this value
	var _deliver_time: int # ms
	var _simulate_ordered_packet_loss: bool = false # for simulating packet drop of RELIABLE packets
	var _reliable: bool = false
	var _reliable_id: int


static func system_fluctuate_latency(ctx: Context):
	if WyncMisc.fast_modulus(Engine.get_physics_frames(), 4) != 0:
		return

	for peer: IOPeer in ctx.peers:
		peer.latency_current_ms = int(ctx.random_generator.randfn(peer.latency_mean_ms, peer.latency_std_dev_ms))
		peer.latency_current_ms = max(0, peer.latency_current_ms)


static func system_flush(ctx: Context):
	var curr_time = Time.get_ticks_msec()

	# look for pending packets to send

	for io_peer: IOPeer in ctx.peers:
		for pkt: Packet in io_peer.out_packets:

			var io_peer_destination := ctx.peers[pkt.to_peer]
			var latency = get_worst_latency(io_peer, io_peer_destination)

			pkt.from_peer = io_peer.peer_id
			pkt._deliver_time = curr_time + latency

			if pkt._simulate_ordered_packet_loss:
				# 3 times latency: (1) first send, dropped; (2) confirming what was received;
				# (3) resending it realizing it was dropped.
				# A transport with redundancy would just need 2.
				pkt._deliver_time = curr_time + latency * 3

			# Note: jitter should be moved to IOPeer
			#if ctx.jitter != 0:
				#pkt._deliver_time += ctx.jitter * ctx.random_generator.randf_range(-1, 1)

			ctx.packets.append(pkt)

		io_peer.out_packets.clear()


static func system_service(ctx: Context):
	var curr_time = Time.get_ticks_msec()

	system_flush(ctx)

	# look for packets ready to be received

	var ids_to_delete: Array[int] = []

	for k in range(ctx.packets.size()):
		var pkt = ctx.packets[k] as Packet
		if curr_time < pkt._deliver_time:
			continue

		var from_peer: IOPeer = ctx.peers[pkt.from_peer]
		if not from_peer:
			print("E: Couldn't find peer %s" % [pkt.from_peer])
			continue
		var to_peer: IOPeer = ctx.peers[pkt.to_peer]
		if not to_peer:
			print("E: Couldn't find peer %s" % [pkt.to_peer])
			continue

		# skip if one peer is disabled
		if from_peer.disabled || to_peer.disabled:

			# drop if unreliable
			if not pkt._reliable:
				ids_to_delete.append(k)
			continue

		# increase reliable index order
		if pkt._reliable:
			var last_pkt_ids: Array[int] = ctx.last_pkt_number_sent_from_peer_to_peer[pkt.from_peer][pkt.to_peer]
			if last_pkt_ids[0] != pkt._reliable_id:
				continue

			# else, deliver and increase last_sent
			last_pkt_ids[0] += 1

		ids_to_delete.append(k)

		# deliver

		to_peer.in_packets.append(pkt)
	
	# remove from right to left
	for i: int in range(ids_to_delete.size()-1, -1, -1):
		var k = ids_to_delete[i]
		ctx.packets.remove_at(k)


static func setup_io_peer(
	io_peer: IOPeer,
	latency_mean_ms: int,
	latency_std_dev_ms: int,
	packet_loss_percentage: int,
	packet_duplicate_percentage: int
	):
	io_peer.latency_mean_ms = latency_mean_ms
	io_peer.latency_std_dev_ms = latency_std_dev_ms
	io_peer.packet_loss_percentage = packet_loss_percentage
	io_peer.packet_duplicate_percentage = packet_duplicate_percentage


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
	# Note: pkt.deliver_time will be later set

	# simulate packet drop of RELIABLE packet

	var io_peer_destination := ctx.peers[to_peer]
	var packet_loss_percentage = get_worst_packet_loss_percentage(io_peer, io_peer_destination)

	if (packet_loss_percentage > 0 &&
		ctx.random_generator.randf() <= (packet_loss_percentage / 100.0)):
		pkt._simulate_ordered_packet_loss = true

	var last_pkt_ids: Array[int] = ctx.last_pkt_number_sent_from_peer_to_peer[pkt.from_peer][pkt.to_peer]
	pkt._reliable_id = last_pkt_ids[1]
	last_pkt_ids[1] += 1

	io_peer.out_packets.append(pkt)


static func queue_unreliable_packet(
		ctx: Context, io_peer: IOPeer, to_peer: int, data: Variant, already_duplicated: bool = false
	):
	var pkt := Packet.new()
	pkt.data = data
	pkt.from_peer = io_peer.peer_id
	pkt.to_peer = to_peer
	pkt._reliable = false
	# packet.deliver_time = it's defined later, not here

	var io_peer_destination := ctx.peers[to_peer]

	# simulate packet duplicates

	var packet_duplicate_percentage = get_worst_packet_duplicate_percentage(io_peer, io_peer_destination)
	if (!already_duplicated &&
		packet_duplicate_percentage > 0 &&
		ctx.random_generator.randf() <= (packet_duplicate_percentage / 100.0)):

		# send a copy
		queue_unreliable_packet(ctx, io_peer, to_peer, data, true)

	# simulate packet drop of UNRELIABLE packet
	
	var packet_loss_percentage = get_worst_packet_loss_percentage(io_peer, io_peer_destination)
	if (packet_loss_percentage > 0 &&
		ctx.random_generator.randf() <= (packet_loss_percentage / 100.0)):
		return

	io_peer.out_packets.append(pkt)


#static func system_caotic_latency(ctx: Context):

	#if Engine.get_physics_frames() % int(Engine.physics_ticks_per_second/2) == 0:
		#ctx._latency_mean += 1
		#if ctx._latency_mean > 600:
			#ctx._latency_mean = 0

static func get_worst_packet_loss_percentage(lhs: IOPeer, rhs: IOPeer):
	return max(lhs.packet_loss_percentage, rhs.packet_loss_percentage)


static func get_worst_latency(lhs: IOPeer, rhs: IOPeer):
	return max(lhs.latency_current_ms, rhs.latency_current_ms)


static func get_worst_packet_duplicate_percentage(lhs: IOPeer, rhs: IOPeer):
	return max(lhs.packet_duplicate_percentage, rhs.packet_duplicate_percentage)

