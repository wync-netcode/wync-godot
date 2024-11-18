extends System
class_name SyNetClockServer
const label: StringName = StringName("SyNetClockServer")

## Extracts state from actors


func _ready():
	components = [CoActor.label, CoCollider.label]
	super()


func on_process(entities, _data, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
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
	var co_io_packets = single_server.get_component(CoIOPackets.label) as CoIOPackets
	var co_server = single_server.get_component(CoServer.label) as CoServer
	
	# prepare packet

	var packet = NetPacketClock.new()
	packet.tick = co_ticks.ticks
	packet.time = ClockUtils.time_get_ticks_msec(co_ticks)
	packet.latency = co_loopback.lag

	# queue for sending

	for peer: CoServer.ServerPeer in co_server.peers:
		var pkt = NetPacket.new()
		pkt.to_peer = peer.peer_id
		pkt.data = packet.duplicate()
		co_io_packets.out_packets.append(pkt)
