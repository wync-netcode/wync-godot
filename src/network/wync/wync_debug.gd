class_name WyncDebug


static var debug_flag1: bool = false
static var debug_flag2: bool = false
static var debug_int1: int = 0


static func log_packet_received(ctx: WyncCtx, packet_type_id: int):
	if not WyncPacketUtil.wync_packet_type_exists(packet_type_id):
		Log.errc(ctx, "Invalid packet_type_id(%s)" % [packet_type_id])
		return
	var history = ctx.debug_packets_received[packet_type_id] as Array[int]
	history[0] += 1


static func packet_received_log_prop_id(ctx: WyncCtx, packet_type_id: int, prop_id: int):
	if not WyncPacketUtil.wync_packet_type_exists(packet_type_id):
		Log.errc(ctx, "Invalid packet_type_id(%s)" % [packet_type_id])
		return
	var history = ctx.debug_packets_received[packet_type_id] as Array[int]
	if ((prop_id + 1) < history.size()):
		history[prop_id +1] += 1
