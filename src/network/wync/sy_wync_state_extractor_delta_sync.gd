extends System
class_name SyWyncStateExtractorDeltaSync
const label: StringName = StringName("SyWyncStateExtractorDeltaSync")

## Extracts state from actors
## NOTE: Maybe it's better to extract only one thing at a time: Full vs Delta
## NOTE: Maybe the loop order should be Client->Prop cause Spatial Relative Synchronization


func on_process(_entities, _data, _delta: float):

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find singleton EnSingleServer")
		return
	var co_io_packets = single_server.get_component(CoIOPackets.label) as CoIOPackets
	#var co_server = single_server.get_component(CoServer.label) as CoServer
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	#var packet_full_snapshot = WyncPktPropSnap.new()
	#packet_full_snapshot.tick = co_ticks.ticks
	#var packet_delta_snapshots = WyncPktPropSnap.new()
	#packet_delta_snapshots.tick = co_ticks.ticks

	#for entity_id_key in ctx.entity_has_props.keys():
		#var prop_ids_array = ctx.entity_has_props[entity_id_key] as Array
		#if not prop_ids_array.size():
			#continue

	# for each client create a packet containing what they need
	# Array <client_id: int, Packet>
	var client_delta_snapshot: Array[WyncPktPropSnapDelta] = []
	client_delta_snapshot.resize(ctx.peers.size())
	for client_id in range(1, ctx.peers.size()):
		client_delta_snapshot[client_id] = WyncPktPropSnapDelta.new()
		
	# --------------------------------------------------------------------------------
	# iterate _delta sync props_
	# --------------------------------------------------------------------------------
	
	for prop_id: int in range(ctx.props.size()):

		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.relative_syncable:
			continue

		for client_id in range(1, ctx.peers.size()):

			# TODO: check client is healthy

			var delta_snapshot = client_delta_snapshot[client_id] as WyncPktPropSnapDelta
			var delta_prop_snap = WyncPktPropSnapDelta.PropSnap.new()
			delta_prop_snap.prop_id = prop_id

			# get last tick received by client

			var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
			if not client_relative_props.has(prop_id):
				client_relative_props[prop_id] = -1
			var client_last_tick = client_relative_props[prop_id]

			# client history too old, need to perform full snapshot, continuing...

			if client_last_tick < ctx.delta_base_state_tick:
				continue

			# TODO: Check does prop has any history to share?

			for i in range(ctx.max_prop_relative_sync_history_ticks):

				# still inside the valid values of Ring

				if i >= prop.relative_change_real_tick.size:
					break

				# try to collect events for these ticks if any

				var event_tick = prop.relative_change_real_tick.get_relative_to_tail(i)
				if event_tick <= client_last_tick:
					continue
				var event_id = prop.relative_change_event_list.get_relative_to_tail(i)

				delta_prop_snap.delta_event_tick.append(event_tick)
				delta_prop_snap.delta_event_id.append(event_id)
				client_relative_props[prop_id] = co_ticks.ticks

			# add what was filled

			if delta_prop_snap.delta_event_id.size() > 0:
				delta_snapshot.snaps.append(delta_prop_snap)


	# queue packets

	for wync_client_id in range(1, ctx.peers.size()):
		var net_peer_id = ctx.peers[wync_client_id]
		var packet_delta_snapshot = client_delta_snapshot[wync_client_id]

		var pkt = NetPacket.new()
		pkt.to_peer = net_peer_id
		pkt.data = WyncUtils.duplicate_any(packet_delta_snapshot)
		co_io_packets.out_packets.append(pkt)
