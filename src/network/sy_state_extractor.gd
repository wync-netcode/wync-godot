extends System
class_name SyStateExtractor
const label: StringName = StringName("SyStateExtractor")

## Extracts state from actors


func _ready():
	components = [CoActor.label, -CoBall.label, CoCollider.label]
	super()


func on_process(entities, _data, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks

	# throttle send rate
	# TODO: make this configurable

	#if co_ticks.ticks % 10 != 0:
		#return
	
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find singleton EnSingleServer")
		return
	var co_io_packets = single_server.get_component(CoIOPackets.label) as CoIOPackets
	var co_server = single_server.get_component(CoServer.label) as CoServer

	# extract actors positional data

	var snapshot = NetSnapshot.new()
	snapshot.entity_ids.resize(entities.size())
	snapshot.positions.resize(entities.size())
	snapshot.velocities.resize(entities.size())
	snapshot.tick = co_ticks.ticks
	
	for i in range(entities.size()):
		var entity = entities[i] as Entity
		var co_actor = entity.get_component(CoActor.label) as CoActor
		var co_collider = entity.get_component(CoCollider.label) as CoCollider

		snapshot.entity_ids[i] = co_actor.id
		snapshot.positions[i] = (co_collider as Node as Node2D).global_position
		snapshot.velocities[i] = (co_collider as Node as CharacterBody2D).velocity

	# prepare packets to send

	for peer: CoServer.ServerPeer in co_server.peers:
		var pkt = NetPacket.new()
		pkt.to_peer = peer.peer_id
		pkt.data = snapshot.duplicate()
		co_io_packets.out_packets.append(pkt)
