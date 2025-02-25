extends System
class_name SyWyncClockServer
const label: StringName = StringName("SyWyncClockServer")

## Periodically send server clock to clients


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_ticks = wync_ctx.co_ticks
	var physics_fps = Engine.physics_ticks_per_second
	
	# throttle send rate

	if co_ticks.ticks % int(physics_fps * 0.5) != 0:
		return
	
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find singleton EnSingleServer")
		return
	
	# prepare packet

	var packet = WyncPktClock.new()
	packet.tick = co_ticks.ticks
	packet.time = ClockUtils.time_get_ticks_msec(co_ticks)
	packet.latency = co_loopback.latency # send raw latency

	# queue for sending

	for wync_peer_id: int in range(1, wync_ctx.peers.size()):

		var packet_dup = WyncUtils.duplicate_any(packet)
		var result = WyncFlow.wync_wrap_packet_out(wync_ctx, wync_peer_id, WyncPacket.WYNC_PKT_CLOCK, packet_dup)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			wync_ctx.out_packets.append(packet_out)
