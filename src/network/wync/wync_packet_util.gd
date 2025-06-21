class_name WyncPacketUtil


static func wync_packet_type_exists(packet_type_id: int) -> bool:
	return packet_type_id >= 0 && packet_type_id < WyncPacket.WYNC_PKT_AMOUNT


## Wraps a valid packet in a WyncPacket in a WyncPacketOut for delivery
## @param packet: void*. A pointer to the packet data
## @returns Tuple[int, WyncPacketOut]. [0] -> Error; [1] -> WyncPacketOut.
static func wync_wrap_packet_out(ctx: WyncCtx, to_wync_peer_id: int, packet_type_id: int, data: Variant) -> Array:

	if not wync_packet_type_exists(packet_type_id):
		Log.err("Invalid packet_type_id(%s)" % [packet_type_id])
		return [1, null]

	var nete_peer_id = WyncJoin.get_nete_peer_id_from_wync_peer_id(ctx, to_wync_peer_id)
	if nete_peer_id == -1:
		Log.err("Couldn't find a nete_peer_id for wync_peer_id(%s)" % [to_wync_peer_id])
		return [2, null]

	var wync_pkt = WyncPacket.new()
	wync_pkt.packet_type_id = packet_type_id
	wync_pkt.data = data

	var wync_pkt_out = WyncPacketOut.new()
	wync_pkt_out.to_nete_peer_id = nete_peer_id
	wync_pkt_out.data = wync_pkt

	return [OK, wync_pkt_out]


"""
static func wync_wrap_packet_out_from_wync_pkt(ctx: WyncCtx, to_wync_peer_id: int, packet_type_id: int, data: WyncPacket) -> Array:

	if not wync_packet_type_exists(packet_type_id):
		Log.err("Invalid packet_type_id(%s)" % [packet_type_id])
		return [1, null]

	var nete_peer_id = WyncTrack.get_nete_peer_id_from_wync_peer_id(ctx, to_wync_peer_id)
	if nete_peer_id == -1:
		Log.err("Couldn't find a nete_peer_id for wync_peer_id(%s)" % [to_wync_peer_id])
		return [2, null]

	var wync_pkt_out = WyncPacketOut.new()
	wync_pkt_out.to_nete_peer_id = nete_peer_id
	wync_pkt_out.data = data

	return [OK, wync_pkt_out]
"""
