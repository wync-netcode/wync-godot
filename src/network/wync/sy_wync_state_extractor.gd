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
	
	# extract data
	
	extract_data_to_tick(wync_ctx, co_ticks, co_ticks.ticks)

	# build packet

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
			
			# ===========================================================
			# Save state history per tick
			
			var state = prop.confirmed_states.get_at(co_ticks.ticks)
			
			var prop_snap = WyncPktPropSnap.PropSnap.new()
			prop_snap.prop_id = prop_id
			prop_snap.prop_value = WyncUtils.duplicate_any(state)
			entity_snap.props.append(prop_snap)
			
			#Log.out(self, "wync: Found prop %s" % prop.name_id)
			
		packet.snaps.append(entity_snap)


	# prepare packets to send

	for peer: CoServer.ServerPeer in co_server.peers:
		var pkt = NetPacket.new()
		pkt.to_peer = peer.peer_id
		pkt.data = packet.duplicate()
		co_io_packets.out_packets.append(pkt)


static func extract_data_to_tick(wync_ctx: WyncCtx, co_ticks: CoTicks, save_on_tick: int = -1):
	
	for entity_id_key in wync_ctx.entity_has_props.keys():

		var prop_ids_array = wync_ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		for prop_id in prop_ids_array:
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			
			# don't extract input values
			# FIXME: should events be extracted? game event yes, but other player events? Maybe we need an option to what events to share.
			# NOTE: what about a setting like: NEVER, TO_ALL, TO_ALL_EXCEPT_OWNER, ONLY_TO_SERVER
			if prop.data_type in [WyncEntityProp.DATA_TYPE.INPUT,
				WyncEntityProp.DATA_TYPE.EVENT]:
				continue

			# relative_syncable receives special treatment

			if prop.relative_syncable:
				# TODO: Move this elsewhere
				var err = update_relative_syncable_prop(wync_ctx, co_ticks, prop_id)
				if err != OK:
					Log.err(wync_ctx, "delta sync | update_relative_syncable_prop err(%s)" % [err])
				continue
			
			# ===========================================================
			# Save state history per tick
			
			prop.confirmed_states.insert_at(save_on_tick, prop.getter.call())


## This function must be ran each frame

static func update_relative_syncable_prop(ctx: WyncCtx, co_ticks: CoTicks, prop_id: int) -> int:
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop = prop as WyncEntityProp
	if not prop.relative_syncable:
		return 2

	# move base_state_tick forward

	var new_base_tick = co_ticks.ticks - ctx.max_prop_relative_sync_history_ticks +1
	if not (ctx.delta_base_state_tick < new_base_tick):
		return 3
	ctx.delta_base_state_tick = new_base_tick

	if prop.relative_change_real_tick.size <= 0:
		return 4

	# update / merge events

	var oldest_event_tick = prop.relative_change_real_tick.get_tail()
	
	if oldest_event_tick != ctx.delta_base_state_tick:
		#Log.err(ctx, "delta sync | not equal %s ==? %s" % [oldest_event_tick, ctx.delta_base_state_tick])
		if oldest_event_tick < ctx.delta_base_state_tick:
			Log.err(ctx, "delta sync | oldest event was skipped")
			return 5
		return 6

	Log.out(ctx, "delta sync | are equal %s ==? %s" % [oldest_event_tick, ctx.delta_base_state_tick])

	# consume delta events
	
	var event_array = prop.relative_change_event_list.pop_tail()
	prop.relative_change_real_tick.pop_tail()

	if event_array is not Array[int]:
		return 7

	Log.out(ctx, "delta sync | found these events %s" % [event_array])

	for event_id: int in event_array:

		# TODO: Make a new function get_event(event_id)
		# TODO: Execute transformation on the data for every event
		# TODO: merge to confirmed_states[0]
		print("delta sync | TODO consume this event_id(%s)" % [event_id])

		pass

	event_array.clear()
	return OK


	
