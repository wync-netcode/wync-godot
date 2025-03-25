extends System
class_name SyWyncClockServer
const label: StringName = StringName("SyWyncClockServer")

## Periodically send server clock to clients
## This service doesn't write state

static func wync_server_sync_clock(ctx: WyncCtx):
	# throttle send rate
	# Note: How often we sync the clock will affect the client's slidding window

	#var physics_fps = Engine.physics_ticks_per_second
	#if ctx.co_ticks.ticks % int(physics_fps * 0.5) != 0:
	if WyncUtils.fast_modulus(ctx.co_ticks.ticks, 16) != 0:
		return
		
	for wync_peer_id: int in range(1, ctx.peers.size()):

		# get latency towards that peer

		var lat_info = ctx.peer_latency_info[wync_peer_id]
		
		# prepare packet

		var packet = WyncPktClock.new()
		packet.tick = ctx.co_ticks.ticks
		packet.time = WyncUtils.clock_get_ms(ctx)
		packet.latency = lat_info.latency_raw_latest_ms # raw latency or stable latency?

		# queue for sending

		var packet_dup = WyncUtils.duplicate_any(packet)
		var result = WyncFlow.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_CLOCK, packet_dup)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)
