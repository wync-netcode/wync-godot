extends System
class_name SyStateExtractor

## Extracts state from actors

func _ready():
	components = "%s,%s" % [CoActor.label, CoCollider.label]
	super()

func on_process(entities, _delta: float):

	# get singletons

	var single_ticks = ECS.get_singleton(self, "EnSingleTicks")
	if not single_ticks:
		print("E: Couldn't find singleton EnSingleTicks")
		return
	var co_ticks = single_ticks.get_component(CoTicks.label) as CoTicks
	
	var single_server = ECS.get_singleton(self, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find singleton EnSingleServer")
		return
	var co_io_packets = single_server.get_component(CoIOPackets.label) as CoIOPackets
	var co_server = single_server.get_component(CoServer.label) as CoServer

	# extract actors positional data

	var snapshot = NetSnapshot.new()
	snapshot.entity_ids.resize(entities.size())
	snapshot.positions.resize(entities.size())
	snapshot.tick = co_ticks.ticks
	
	for i in range(entities.size()):
		var entity = entities[i] as Entity
		var co_actor = entity.get_component(CoActor.label) as CoActor
		var node2d = entity as Node2D

		snapshot.entity_ids[i] = co_actor.id
		snapshot.positions[i] = node2d.position
	
	# NOTE: Might want no to cleaning the buffer

	co_io_packets.out_packets.clear()

	# prepare packets to send

	for peer: CoServer.ServerPeer in co_server.peers:
		var pkt = NetPacket.new()
		pkt.to_peer = peer.peer_id
		pkt.data = snapshot.duplicate()
		co_io_packets.out_packets.append(pkt)
