extends System
class_name SyTransportLoopback

## Fake network that sends and receives packets between peers


func _ready():
	components = "%s" % [CoIOPackets.label]
	super()

	
func on_process_entity(entity: Entity, _delta: float):

	var curr_time = Time.get_ticks_msec()

	# components

	var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets
	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return
		
	# look for pending packets to send

	for pkt: NetPacket in co_io_packets.out_packets:
		var loopback_pkt = LoopbackPacket.new()
		loopback_pkt.packet = pkt
		loopback_pkt.deliver_time = curr_time + co_loopback.lag

		# NOTE: shouldn't the packet be erased here?

		co_loopback.packets.append(loopback_pkt)

	# look for packets ready to be received

	for pkt: LoopbackPacket in co_loopback.packets:
		if curr_time < pkt.deliver_time:
			continue

		co_loopback.packets.erase(pkt)

		# get destination buffer from registered peers

		var peer: LoopbackPeer = co_loopback.peers[pkt.packet.to_peer]
		if not peer:
			print("E: Couldn't find peer %s" % [pkt.packet.to_peer])
			continue

		# deliver

		var buffer: CoIOPackets = peer.peer_packet_buffer
		buffer.in_packets.append(pkt.packet)
