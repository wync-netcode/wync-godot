extends System
class_name SyWyncClockServer
const label: StringName = StringName("SyWyncClockServer")

## Periodically send server clock to clients


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	WyncFlow.wync_client_set_current_latency(ctx, co_loopback.latency)
	#wync_server_sync_clock(ctx)
	
	
## This service doesn't write state

static func wync_server_sync_clock(ctx: WyncCtx):
	# throttle send rate

	var physics_fps = Engine.physics_ticks_per_second
	if ctx.co_ticks.ticks % int(physics_fps * 0.5) != 0:
		return
	
	# prepare packet

	var packet = WyncPktClock.new()
	packet.tick = ctx.co_ticks.ticks
	packet.time = ClockUtils.time_get_ticks_msec(ctx.co_ticks)
	packet.latency = ctx.current_tick_nete_latency_ms # send raw latency

	# queue for sending

	for wync_peer_id: int in range(1, ctx.peers.size()):

		var packet_dup = WyncUtils.duplicate_any(packet)
		var result = WyncFlow.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_CLOCK, packet_dup)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, false)
