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

		wync_handle_pkt_prop_snap(wync_ctx, data)

		co_io.in_packets.remove_at(k)


static func wync_handle_pkt_prop_snap(ctx: WyncCtx, data: Variant):

	if data is not WyncPktPropSnap:
		return 1
	data = data as WyncPktPropSnap
	
	for snap: WyncPktPropSnap.EntitySnap in data.snaps:
		
		if not WyncUtils.is_entity_tracked(ctx, snap.entity_id):
			Log.err("couldn't find entity (%s) skipping..." % [snap.entity_id], Log.TAG_LATEST_VALUE)
			continue
		
		for prop: WyncPktPropSnap.PropSnap in snap.props:
			
			var local_prop = WyncUtils.get_prop(ctx, prop.prop_id)
			if local_prop == null:
				Log.err("couldn't find prop (%s) skipping..." % [prop.prop_id], Log.TAG_LATEST_VALUE)
				continue
			local_prop = local_prop as WyncEntityProp
			if local_prop.relative_syncable:
				continue
			
			# NOTE: two tick datas could have arrive at the same tick
			local_prop.last_ticks_received.push(data.tick)
			local_prop.confirmed_states.insert_at(data.tick, prop.prop_value)
			local_prop.arrived_at_tick.insert_at(data.tick, ctx.co_ticks.ticks)
			local_prop.just_received_new_state = true

			if local_prop.is_auxiliar_prop:
				# notify _main delta prop_ about the updates
				var delta_prop = WyncUtils.get_prop(ctx, local_prop.auxiliar_delta_events_prop_id) as WyncEntityProp
				delta_prop.just_received_new_state = true


		# process relative syncable separatedly for now to reason about them separatedly

		for prop: WyncPktPropSnap.PropSnap in snap.props:
			
			var local_prop = WyncUtils.get_prop(ctx, prop.prop_id)
			if local_prop == null:
				Log.err("couldn't find prop (%s) skipping..." % [prop.prop_id], Log.TAG_LATEST_VALUE)
				continue
			local_prop = local_prop as WyncEntityProp
			if not local_prop.relative_syncable:
				continue

			# TODO: overwrite real data, clear all delta events, etc.
			# if a _predicted delta prop_ receives fullsnapshot cleanup must be done
			# if a delta prop receives a fullsnapshot we have no other option but to comply

			local_prop.setter.call(prop.prop_value)
			local_prop.just_received_new_state = true
			var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
			delta_props_last_tick[prop.prop_id] = data.tick
			Log.out("delta sync debug1 | ser_tick(%s) delta_prop_last_tick %s" % [ctx.co_ticks.server_ticks, delta_props_last_tick], Log.TAG_LATEST_VALUE)

			# TODO: reset event buffer, clean events that should already be applied by this tick
			# Reset it but only for one prop
			# SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(ctx)

	# update last tick received
	ctx.last_tick_received = max(ctx.last_tick_received, data.tick)


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
