extends System
class_name SyWyncSaveConfirmedStates
const label: StringName = StringName("SyWyncSaveConfirmedStates")

# TODO: This preferable would be in process


func _ready():
	components = [CoClient.label, CoPeerRegisteredFlag.label]
	super()
	

func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err("Couldn't find singleton EnSingleClient", Log.TAG_LATEST_VALUE)
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktPropSnap
		if not data:
			continue

		WyncFlow.wync_handle_pkt_prop_snap(wync_ctx, data)

		co_io.in_packets.remove_at(k)


"""
func save_delta_snap_from_packets(ctx: WyncCtx, co_io: CoIOPackets):

	# save tick data from packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktPropSnapDelta
		if not data:
			continue
		co_io.in_packets.remove_at(k)
		
		for snap: WyncPktPropSnapDelta.PropSnap in data.snaps:
			
			#if not WyncUtils.is_entity_tracked(wync_ctx, snap.entity_id):
				#continue
			
			#for prop: WyncPktPropSnap.PropSnap in snap.props:
				
			var local_prop = WyncUtils.get_prop(ctx, snap.prop_id)
			if local_prop == null:
				Log.err(self, "delta sync | Received delta events for a prop I couldn't find id(%s)" % [snap.prop_id])
				continue
			local_prop = local_prop as WyncEntityProp
			if not local_prop.relative_syncable:
				Log.err(self, "delta sync | Received delta events for a Prop which isn't relative_syncable id(%s) event_id(%s)" % [snap.prop_id, snap.delta_event_id_list])
				continue

			var max_event_tick = 0

			for i in range(snap.delta_event_tick_list.size()):
				var event_tick = snap.delta_event_tick_list[i] as int
				var event_ids = snap.delta_event_id_list[i] as Array[int]
				max_event_tick = max(max_event_tick, event_tick)

				var err1 = local_prop.relative_change_real_tick.push_head(event_tick)
				var err2 = local_prop.relative_change_event_list.extend_head()
				if (err1 + err2) != OK:
					Log.err(ctx, "delta sync | extend_head, push_head | err1(%s) err2(%s)" % [err1, err2])
					continue

				var event_array = local_prop.relative_change_event_list.get_head()
				event_array = event_array as Array[int]
				event_array.clear()

				for event_id: int in event_ids:
					Log.out(self, "delta sync | received event_id(%s) for tick(%s)" % [event_id, event_tick])
					event_array.push_back(event_id)
			
			local_prop.just_received_new_state = true

			# update last received tick for delta sync prop
			var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
			if not delta_props_last_tick.has(snap.prop_id):
				delta_props_last_tick[snap.prop_id] = max_event_tick
			else:
				delta_props_last_tick[snap.prop_id] = max(max_event_tick, delta_props_last_tick[snap.prop_id])
"""
