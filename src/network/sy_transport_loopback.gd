extends System
class_name SyTransportLoopback
const label: StringName = StringName("SyTransportLoopback")

## Fake network that sends and receives packets between peers


func _ready():
	components = [CoIOPackets.label]
	super()

## NOTE: This system runs on "_on_process" (render frames)
	
func on_process_entity(entity: Entity, _data, _delta: float):

	var curr_time = Time.get_ticks_msec()

	# components

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		print("E: Couldn't find singleton CoTransportLoopback")
		return

	# ready to simulate

	co_loopback.simulation_delta_acumulator += _delta
	#Log.out(self, "Simulating ??? %s" % (co_loopback.simulation_delta_acumulator * 1000))
	
	if co_loopback.simulation_delta_acumulator * 1000 < co_loopback.simulate_every_ms:
		#Log.out(self, "Simulating NOO %s" % (co_loopback.simulation_delta_acumulator * 1000))
	
		return
	co_loopback.simulation_delta_acumulator = 0
	#Log.out(self, "Simulating YES %s" % (co_loopback.simulation_delta_acumulator * 1000))
	
	var co_io_packets = entity.get_component(CoIOPackets.label) as CoIOPackets
		
	# look for pending packets to send

	for pkt: NetPacket in co_io_packets.out_packets:
		var loopback_pkt = LoopbackPacket.new()
		loopback_pkt.packet = pkt
		loopback_pkt.deliver_time = curr_time + co_loopback.latency
		co_loopback.packets.append(loopback_pkt)
		#Log.out(self, "consume | sent 1 packet")

	co_io_packets.out_packets.clear()

	# look for packets ready to be received

	#Log.out(self, "consume | curr_time %s" % [curr_time])

	var amount = 0

	for k in range(co_loopback.packets.size()-1, -1, -1):
		var pkt = co_loopback.packets[k] as LoopbackPacket
		if curr_time < pkt.deliver_time:
			continue
			
		# consume
		co_loopback.packets.remove_at(k)

		# get destination buffer from registered peers

		var peer: LoopbackPeer = co_loopback.peers[pkt.packet.to_peer]
		if not peer:
			print("E: Couldn't find peer %s" % [pkt.packet.to_peer])
			continue

		# deliver

		var buffer: CoIOPackets = peer.peer_packet_buffer
		buffer.in_packets.append(pkt.packet)

		#Log.out(self, "consume | received 1 packet, size %s curr_time %s deliver_time %s" % [buffer.in_packets.size(), curr_time, pkt.deliver_time])
		amount += 1
		if buffer.in_packets.size() >= 2:
			print("break")
		
