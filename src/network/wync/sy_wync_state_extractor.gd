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
	
	
## Ideal loop
## * Sync all VIP props
## * Sync all other props
## This service writes state (ctx.client_has_relative_prop_has_last_tick)
static func wync_send_extracted_data(ctx: WyncCtx):

	var data_used = 0

	# TODO: Allocate a LIST OF PACKETS, because we're gonna be generating all kinds of packets:
	# * On C use a custom byte buffer, it's only use locally so no need to make it complex
	# 1. WyncPktSnap (each varies in size...)
	# 2. WyncPktInputs (are all the same size, but their size is (User) configurable)
	# 3. WyncPktEventData (varies in size)

	# byte buffer
	# Array < client_id: int, List < WyncPacket > >
	# Array < client_id: int, Array < idx: int, WyncPacket > >
	# Array[Array[WyncPacket]]
	var clients_packet_buffer := [] as Array[Array]
	clients_packet_buffer.resize(ctx.peers.size())
	for client_id: int in range(1, ctx.peers.size()):
		clients_packet_buffer[client_id] = [] as Array[WyncPacket]

	# build packet

	for pair: WyncCtx.PeerEntityPair in ctx.queue_entity_pairs_to_sync:
		var client_id = pair.peer_id
		var entity_id = pair.entity_id

		var packet_buffer := clients_packet_buffer[client_id] as Array[WyncPacket]
		var packet_snap := WyncPktSnap.new()
		packet_snap.tick = ctx.co_ticks.ticks

		# TODO (1): Notify wync this entity was successfully updated
		# wync_mark_entity_as_updated
		# wync_remove_entity_from_update_queue(ctx, entity_id, client_id)
		# TODO (2): Notify wync user has last tick
		# client_prop_last_tick[prop_id] = co_ticks.tick

		WyncThrottle.wync_remove_entity_from_sync_queue(ctx, client_id, entity_id)

		# plan: fill all the data for the props, then see if it fits

		var prop_ids_array = ctx.entity_has_props[entity_id] as Array
		if not prop_ids_array.size():
			continue

		for prop_id in prop_ids_array:
			var prop = WyncUtils.get_prop(ctx, prop_id)
			if prop == null:
				continue
			prop = prop as WyncEntityProp

			# ignore inputs
			if prop.data_type == WyncEntityProp.DATA_TYPE.INPUT:
				continue

			# sync events, including their data
			# auxiliar props are included here... ?
			elif prop.data_type == WyncEntityProp.DATA_TYPE.EVENT:

				# this includes _regular_ and _auxiliar_ props
				var pkt_input := SyWyncStateExtractorDeltaSync.wync_prop_event_send_event_ids_to_peer (ctx, prop_id)
				if not (pkt_input != null && pkt_input is WyncPktInputs):
					Log.errc(ctx, "Couldn't create input packet")
					assert(false)
					continue

				if pkt_input != null && pkt_input is WyncPktInputs:
					# commit
					var packet = WyncPacket.new()
					packet.packet_type_id = WyncPacket.WYNC_PKT_INPUTS
					packet.data = pkt_input
					data_used += HashUtils.calculate_object_data_size(packet)
					packet_buffer.append(packet)

				# compile event ids
				var event_ids := [] as Array[int]
				event_ids.resize(pkt_input.inputs.size())
				for input: WyncPktInputs.NetTickDataDecorator in pkt_input.inputs:
					for event_id: int in input.data as Array[int]:
						event_ids.append(event_id)

				# get event data
				var pkt_event_data = SyWyncSendEventData.wync_get_event_data_packet(ctx, client_id, event_ids)
				if pkt_event_data.events.size() > 0:
					# commit
					var packet = WyncPacket.new()
					packet.packet_type_id = WyncPacket.WYNC_PKT_EVENT_DATA
					packet.data = pkt_event_data
					data_used += HashUtils.calculate_object_data_size(packet)
					packet_buffer.append(packet)

				# update last tick
				# TODO: move this to it's own function
				var delta_prop_last_tick = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
				delta_prop_last_tick[prop.auxiliar_delta_events_prop_id] = ctx.co_ticks.ticks

				#Log.outc(ctx, "tag1 | this is my pkt_input %s" % [JsonClassConverter.class_to_json_string(pkt_input)])
				#Log.outc(ctx, "tag1 | this is my pkt_event_data %s" % [JsonClassConverter.class_to_json_string(pkt_event_data)])

			# relative syncable receives special treatment?
			elif prop.relative_syncable:
				if prop.timewarpable: # NOT supported: relative_syncable + timewarpable
					continue
				var snap_prop = _wync_sync_relative_prop_base_only(ctx, prop_id, client_id)
				if snap_prop != null && snap_prop is WyncPktSnap.SnapProp:
					packet_snap.snaps.append(snap_prop)

			## regular declarative prop
			else:

				var snap_prop = _wync_sync_regular_prop(ctx, prop_id)
				if snap_prop != null && snap_prop is WyncPktSnap.SnapProp:
					#Log.outc(ctx, "tag1 | extracted this prop %s" % [HashUtils.object_to_dictionary(snap_prop)])
					packet_snap.snaps.append(snap_prop)
				else:
					Log.outc(ctx, "tag1 | came empty handed")

		# commit packet WyncPkySnap

		if packet_snap.snaps.size() > 0:
			var packet = WyncPacket.new()
			packet.packet_type_id = WyncPacket.WYNC_PKT_PROP_SNAP
			packet.data = packet_snap
			data_used += HashUtils.calculate_object_data_size(packet)
			packet_buffer.append(packet)
			#Log.outc(ctx, "tag1 | appended to packet_snap %s" % [HashUtils.object_to_dictionary(packet_snap)])
			#assert(false)

		# exeeded size, stop

		if (data_used >= ctx.out_packets_size_remaining_chars):
			break

	# queue _out packets_ for delivery

	for client_id: int in range(1, ctx.peers.size()):
		var packet_buffer := clients_packet_buffer[client_id] as Array[WyncPacket]

		for packet: WyncPacket in packet_buffer:
			var packet_dup = WyncUtils.duplicate_any(packet.data)

			var result = WyncFlow.wync_wrap_packet_out(ctx, client_id, packet.packet_type_id, packet_dup)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, true)
				#Log.outc(ctx, "tag1 | server packet out %s %s" % [WyncPacket.PKT_NAMES[packet_out.data.packet_type_id], HashUtils.object_to_dictionary(packet_out.data.data)])
			else:
				Log.errc(ctx, "tag1 | bad result here mate")


static func _wync_sync_regular_prop(ctx: WyncCtx, prop_id: int) -> WyncPktSnap.SnapProp:

	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return null
	prop = prop as WyncEntityProp

	# copy cached data
	
	var state = prop.confirmed_states.get_at(ctx.co_ticks.ticks)

	# build packet

	var prop_snap := WyncPktSnap.SnapProp.new()
	prop_snap.prop_id = prop_id
	prop_snap.state = WyncUtils.duplicate_any(state)

	return prop_snap

			
# process delta props separatedly for now
# --------------------------------------------------

static func _wync_sync_relative_prop_base_only(
	ctx: WyncCtx,
	prop_id: int,
	client_id: int
	) -> WyncPktSnap.SnapProp:

	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return null
	prop = prop as WyncEntityProp

	# send fullsnapshot if client doesn't have history, or if it's too old

	var client_relative_props = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
	if not client_relative_props.has(prop_id):
		client_relative_props[prop_id] = -1
	if client_relative_props[prop_id] >= ctx.delta_base_state_tick:
		return null
	
	# ===========================================================
	# Save state history per tick
	
	var state = prop.getter.call() # getter already gives a copy
	var prop_snap = WyncPktSnap.SnapProp.new()
	prop_snap.prop_id = prop_id
	prop_snap.state = state

	client_relative_props[prop_id] = ctx.co_ticks.ticks

	return prop_snap


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


	
