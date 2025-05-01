extends System
class_name SyWyncClockServer
const label: StringName = StringName("SyWyncClockServer")


static func wync_server_handle_clock_req(ctx: WyncCtx, data: Variant, from_nete_peer_id: int):
	
	if data is not WyncPktClock:
		return 1
	data = data as WyncPktClock

	var wync_peer_id = WyncUtils.is_peer_registered(ctx, from_nete_peer_id)
	if wync_peer_id < 0:
		Log.errc(ctx, "client %s is not registered" % from_nete_peer_id)
		return 3
	
	# prepare packet

	var packet = WyncPktClock.new()
	packet.time_og = data.time_og
	packet.tick = ctx.co_ticks.ticks
	packet.time = WyncUtils.clock_get_ms(ctx)

	# queue for sending

	var result = WyncFlow.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_CLOCK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)


static func wync_client_ask_for_clock(ctx: WyncCtx):

	if WyncUtils.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
		return

	var packet = WyncPktClock.new()
	packet.time_og = WyncUtils.clock_get_ms(ctx)

	# prepare peer packet and send (queue)

	var result = WyncFlow.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_CLOCK, packet)
	if result[0] == OK:
		var packet_out = result[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)
