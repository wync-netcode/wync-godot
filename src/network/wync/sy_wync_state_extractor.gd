extends System
class_name SyWyncStateExtractor
const label: StringName = StringName("SyWyncStateExtractor")

## Extracts state from actors


func on_process(_entities, _data, _delta: float):

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	# throttle send rate
	# TODO: make this configurable

	#if co_ticks.ticks % 10 != 0:
		#return
	
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		print("E: Couldn't find singleton EnSingleServer")
		return
	
	# extract data
	
	extract_data_to_tick(ctx, ctx.co_ticks, ctx.co_ticks.ticks)
	
	# send data
	
	wync_send_extracted_data(ctx)
	
	
static func wync_send_extracted_data(ctx: WyncCtx):

	# TODO: iterate per each client, maybe make it configurable, cause some updates might be global
	# Only run if there is at least one client (peer_id 0 is server)
	if ctx.peers.size() <= 1:
		return

	var co_ticks = ctx.co_ticks
	var client_id = 1 # FIXME: Remove hardcoded client_id

	# build packet

	var packet = WyncPktPropSnap.new()
	packet.tick = co_ticks.ticks
	
	for entity_id_key in ctx.entity_has_props.keys():
		var prop_ids_array = ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		var entity_snap = WyncPktPropSnap.EntitySnap.new()
		entity_snap.entity_id = entity_id_key
		
		for prop_id in prop_ids_array:
			var prop = WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			prop = prop as WyncEntityProp
			# don't extract input values
			# FIXME: should events be extracted? game event yes, but other player events?
			# Maybe we need an option to what events to share.
			# NOTE: what about a setting like: NEVER, TO_ALL, TO_ALL_EXCEPT_OWNER, ONLY_TO_SERVER
			if prop.data_type in [WyncEntityProp.DATA_TYPE.INPUT,
				WyncEntityProp.DATA_TYPE.EVENT]:
				continue

			# TODO: Allow EVENT props if it doesn't belong to a client
			# TODO: TYPE_EVENT props should be sent in chunks, not here
			# Allow auxiliar props to be synced
			if prop.relative_syncable:
				var prop_aux = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
				if prop_aux == null:
					continue
				prop_id = prop.auxiliar_delta_events_prop_id
				prop = prop_aux
			
			# ===========================================================
			# Save state history per tick
			
			var state = prop.confirmed_states.get_at(co_ticks.ticks)
			var prop_snap = WyncPktPropSnap.PropSnap.new()
			prop_snap.prop_id = prop_id
			prop_snap.prop_value = WyncUtils.duplicate_any(state)
			entity_snap.props.append(prop_snap)

		
		# process delta props separatedly for now
		# --------------------------------------------------

		for prop_id in prop_ids_array:
			var prop = WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			prop = prop as WyncEntityProp
			if not prop.relative_syncable:
				continue
			if prop.timewarpable:
				# TODO: currently not implemented
				continue

			# send fullsnapshot if client doesn't have history, or if it's too old

			var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
			if not client_relative_props.has(prop_id):
				client_relative_props[prop_id] = -1
			if client_relative_props[prop_id] >= ctx.delta_base_state_tick:
				continue
			client_relative_props[prop_id] = co_ticks.ticks
			
			# ===========================================================
			# Save state history per tick
			
			var state = prop.getter.call() # getter already gives a copy
			var prop_snap = WyncPktPropSnap.PropSnap.new()
			prop_snap.prop_id = prop_id
			prop_snap.prop_value = state
			entity_snap.props.append(prop_snap)
			
			#Log.out(self, "wync: Found prop %s" % prop.name_id)
			
			
		packet.snaps.append(entity_snap)


	# queue _out packets_ for delivery

	for wync_peer_id: int in range(1, ctx.peers.size()):

		var packet_dup = WyncUtils.duplicate_any(packet)
		var result = WyncFlow.wync_wrap_packet_out(ctx, wync_peer_id, WyncPacket.WYNC_PKT_PROP_SNAP, packet_dup)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			ctx.out_packets.append(packet_out)


static func extract_data_to_tick(ctx: WyncCtx, co_ticks: CoTicks, save_on_tick: int = -1):
	
	for entity_id_key in ctx.entity_has_props.keys():

		var prop_ids_array = ctx.entity_has_props[entity_id_key] as Array
		if not prop_ids_array.size():
			continue
		
		for prop_id in prop_ids_array:
			
			var prop = ctx.props[prop_id] as WyncEntityProp
			
			# don't extract input values
			# FIXME: should events be extracted? game event yes, but other player events? Maybe we need an option to what events to share.
			# NOTE: what about a setting like: NEVER, TO_ALL, TO_ALL_EXCEPT_OWNER, ONLY_TO_SERVER
			if prop.data_type in [WyncEntityProp.DATA_TYPE.INPUT,
				WyncEntityProp.DATA_TYPE.EVENT]:
				continue

			# relative_syncable receives special treatment

			if prop.relative_syncable:
				var err = update_relative_syncable_prop(ctx, co_ticks, prop_id)
				if err != OK:
					Log.err("delta sync | update_relative_syncable_prop err(%s)" % [err])
				
				# Allow auxiliar props
				var prop_aux = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
				if prop_aux == null:
					continue
				prop = prop_aux
			
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
	
	# on new tick, clear all events?
	return OK

	"""

	if prop.relative_change_real_tick.size <= 0:
		return OK

	# update / merge events

	var oldest_event_tick = prop.relative_change_real_tick.get_tail()
	
	if oldest_event_tick != ctx.delta_base_state_tick:
		#Log.err(ctx, "delta sync | not equal %s ==? %s" % [oldest_event_tick, ctx.delta_base_state_tick])
		if oldest_event_tick < ctx.delta_base_state_tick:
			Log.err(ctx, "delta sync | oldest event was skipped")
			return 5
		return 6

	#Log.out(ctx, "delta sync | are equal %s ==? %s" % [oldest_event_tick, ctx.delta_base_state_tick])

	# consume delta events
	
	var event_array = prop.relative_change_event_list.pop_tail()
	prop.relative_change_real_tick.pop_tail()

	if event_array is not Array[int]:
		return 7

	Log.out(ctx, "delta sync | gonna consume these events %s" % [event_array])

	# NOTE: Actually applying the events to the base should be done if timewarpable
	# (in that case we actually have a base)
	#for event_id: int in event_array:
		#WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)
		#pass

	event_array.clear()
	return OK
	"""


	
