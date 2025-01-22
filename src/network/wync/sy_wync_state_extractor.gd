extends System
class_name SyWyncStateExtractor
const label: StringName = StringName("SyWyncStateExtractor")

## Extracts state from actors


func on_process(_entities, _data, _delta: float):

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
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# extract actors positional data

	var packet = WyncPktPropSnap.new()
	packet.tick = co_ticks.ticks
	
	for entity_id_key in wync_ctx.entity_has_props.keys():
		var prop_ids_array = wync_ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		var entity_snap = WyncPktPropSnap.EntitySnap.new()
		entity_snap.entity_id = entity_id_key
		
		for prop_id in prop_ids_array:
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			
			# don't extract input values
			# FIXME: should events be extracted? game event yes, but other player events? Maybe we need an option to what events to share.
			# NOTE: what about a setting like: NEVER, TO_ALL, TO_ALL_EXCEPT_OWNER, ONLY_TO_SERVER
			if prop.data_type in [WyncEntityProp.DATA_TYPE.INPUT,
				WyncEntityProp.DATA_TYPE.EVENT]:
				continue
			
			var prop_snap = WyncPktPropSnap.PropSnap.new()
			
			prop_snap.prop_id = prop_id
			prop_snap.prop_value = prop.getter.call()
			entity_snap.props.append(prop_snap)
			
			#Log.out(self, "wync: Found prop %s" % prop.name_id)
			
		packet.snaps.append(entity_snap)


	# prepare packets to send

	for peer: CoServer.ServerPeer in co_server.peers:
		var pkt = NetPacket.new()
		pkt.to_peer = peer.peer_id
		pkt.data = packet.duplicate()
		co_io_packets.out_packets.append(pkt)
