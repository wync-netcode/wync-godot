class_name WyncPacketUtil


static func wync_packet_type_exists(packet_type_id: int) -> bool:
	return packet_type_id >= 0 && packet_type_id < WyncPacket.WYNC_PKT_AMOUNT


## Wraps a valid packet in a WyncPacket in a WyncPacketOut for delivery
## @param packet: void*. A pointer to the packet data
## @returns Tuple[int, WyncPacketOut]. [0] -> Error; [1] -> WyncPacketOut.
static func wync_wrap_packet_out(ctx: WyncCtx, to_wync_peer_id: int, packet_type_id: int, data: Variant) -> Array:

	if not wync_packet_type_exists(packet_type_id):
		Log.errc(ctx, "Invalid packet_type_id(%s)" % [packet_type_id])
		return [1, null]

	var nete_peer_id = WyncJoin.get_nete_peer_id_from_wync_peer_id(ctx, to_wync_peer_id)
	if nete_peer_id == -1:
		Log.errc(ctx, "Couldn't find a nete_peer_id for wync_peer_id(%s)" % [to_wync_peer_id])
		return [2, null]

	var wync_pkt = WyncPacket.new()
	wync_pkt.packet_type_id = packet_type_id
	wync_pkt.data = data

	var wync_pkt_out = WyncPacketOut.new()
	wync_pkt_out.to_nete_peer_id = nete_peer_id
	wync_pkt_out.data = wync_pkt

	return [OK, wync_pkt_out]


## FIXME: do not return an array, return a struct
## In case we can't queue a packet stop generatin' packets
## @argument dont_occuppy: bool. Used for inserting packets which size was already reserved
## @returns int: Error
static func wync_try_to_queue_out_packet (
	ctx: WyncCtx,
	out_packet: WyncPacketOut,
	reliable: bool,
	already_commited: bool,
	dont_ocuppy: bool = false,
	) -> int:

	var packet_size = HashUtils.calculate_wync_packet_data_size(out_packet.data.packet_type_id)
	if packet_size >= ctx.out_packets_size_remaining_chars:
		if already_commited:
			#Log.err("(%s) COMMITED anyways, Packet too big (%s), remaining data (%s), d(%s)" %
			#[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id],
			#packet_size,
			#ctx.out_packets_size_remaining_chars,
			#packet_size-ctx.out_packets_size_remaining_chars])
			pass
		else:
			Log.errc(ctx, "(%s) DROPPED, Packet too big (%s), remaining data (%s), d(%s)" %
			[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id],
			packet_size,
			ctx.out_packets_size_remaining_chars,
			packet_size-ctx.out_packets_size_remaining_chars])
			return 1

	if not dont_ocuppy:
		ctx.out_packets_size_remaining_chars -= packet_size
	
	if reliable:
		ctx.out_reliable_packets.append(out_packet)
	else:
		ctx.out_unreliable_packets.append(out_packet)

	#Log.outc(ctx, "queued packet %s, remaining data (%s)" %
	#[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id], ctx.out_packets_size_remaining_chars])
	return OK


## Just like the function above, except this just "ocuppies" space without queuing anything
## Used for preserving space for queuing event data.
static func wync_ocuppy_space_towards_packets_data_size_limit(ctx: WyncCtx, chars: int):
	ctx.out_packets_size_remaining_chars -= chars


## Call every time before gathering packets
static func wync_set_data_limit_chars_for_out_packets(ctx: WyncCtx, data_limit_chars: int):
	ctx.out_packets_size_limit = data_limit_chars
	ctx.out_packets_size_remaining_chars = data_limit_chars
