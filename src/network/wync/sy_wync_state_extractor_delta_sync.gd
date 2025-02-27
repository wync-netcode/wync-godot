extends System
class_name SyWyncStateExtractorDeltaSync
const label: StringName = StringName("SyWyncStateExtractorDeltaSync")

## This system name isn't very precise TODO: rename
## Collects what events ids must be synced with each client
## Collects what event data must be synced with each client
## NOTE: Maybe the loop order should be Client->Prop cause Spatial Relative Synchronization


func on_process(_entities, _data, _delta: float):
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx

	send_event_ids_to_peers(ctx)
	queue_event_data_to_be_synced_to_peers(ctx)


# --------------------------------------------------------------------------------
# Service 1: Send all event_ids to clients
# TODO: For now all clients know about this prop, later we can filter


static func send_event_ids_to_peers(ctx: WyncCtx):

	var co_ticks = ctx.co_ticks

	# reset events

	for wync_client_id in range(1, ctx.peers.size()):
		var event_set = ctx.peers_events_to_sync[wync_client_id] as Dictionary
		event_set.clear()

	for prop_id: int in range(ctx.props.size()):

		# base prop
		var base_prop = WyncUtils.get_prop(ctx, prop_id)
		if base_prop == null:
			continue
		base_prop = base_prop as WyncEntityProp
		if not base_prop.relative_syncable:
			continue

		# auxiliar prop
		var aux_prop = WyncUtils.get_prop(ctx, base_prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			continue
		aux_prop = aux_prop as WyncEntityProp
		if aux_prop.data_type != WyncEntityProp.DATA_TYPE.EVENT:
			Log.err("auxiliar prop id(%s) is not EVENT" % prop_id, Log.TAG_DELTA_EVENT)
			continue

		# prepare packet

		var pkt_inputs = WyncPktInputs.new()

		for tick in range(co_ticks.ticks - CoNetBufferedInputs.AMOUNT_TO_SEND, co_ticks.ticks +1):
			var input = aux_prop.confirmed_states.get_at(tick)
			if input == null:
				Log.err("we don't have an input for this tick %s" % [tick], Log.TAG_DELTA_EVENT)
				continue
			
			var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
			tick_input_wrap.tick = tick
			
			var copy = WyncUtils.duplicate_any(input)
			if copy == null:
				Log.out("WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_DELTA_EVENT)
			tick_input_wrap.data = copy if copy != null else input
				
			pkt_inputs.inputs.append(tick_input_wrap)

		pkt_inputs.amount = pkt_inputs.inputs.size()
		pkt_inputs.prop_id = prop_id

		# queue packets to send
		# TODO: Make this upper level maybe?

		for wync_client_id in range(1, ctx.peers.size()):
			var packet_dup = WyncUtils.duplicate_any(pkt_inputs)
			var result = WyncFlow.wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_INPUTS, packet_dup)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				ctx.out_packets.append(packet_out)


# --------------------------------------------------------------------------------
# Service 2: For each peer collect what _event data_ they need
# collect what event_ids need their _event data_ synced depending on peer


static func queue_event_data_to_be_synced_to_peers(ctx: WyncCtx):

	var co_ticks = ctx.co_ticks

	for entity_id: int in ctx.tracked_entities.keys():

		for wync_client_id in range(1, ctx.peers.size()):

			# TODO: check peer is healthy

			if not ctx.clients_sees_entities[wync_client_id].has(entity_id):
				continue

			for prop_id: int in ctx.entity_has_props[entity_id]:

				var base_prop = WyncUtils.get_prop(ctx, prop_id)
				if base_prop == null:
					continue
				base_prop = base_prop as WyncEntityProp
				if not base_prop.relative_syncable:
					continue

				var aux_prop = WyncUtils.get_prop(ctx, base_prop.auxiliar_delta_events_prop_id)
				if aux_prop == null:
					continue
				aux_prop = aux_prop as WyncEntityProp
				if aux_prop.data_type != WyncEntityProp.DATA_TYPE.EVENT:
					Log.err("auxiliar prop id(%s) is not EVENT" % prop_id, Log.TAG_DELTA_EVENT)
					continue

				# get last tick received by client

				var delta_prop_last_tick = ctx.client_has_relative_prop_has_last_tick[wync_client_id] as Dictionary
				var client_last_tick = delta_prop_last_tick[prop_id]

				# client history too old, need to perform full snapshot, continuing...

				if client_last_tick < ctx.delta_base_state_tick:
					Log.out("delta sync | client_last_tick too old, needs full snapshot, skipping...", Log.TAG_DELTA_EVENT)
					continue

				var event_set = ctx.peers_events_to_sync[wync_client_id] as Dictionary
				var range_tick_start = max(co_ticks.ticks - CoNetBufferedInputs.AMOUNT_TO_SEND, client_last_tick +1)

				for tick: int in range(range_tick_start, co_ticks.ticks + 1):

					# get _delta events_ for this tick
					var input = aux_prop.confirmed_states.get_at(tick)
					if input is not Array[int]:
						Log.err("we don't have an input for this tick %s" % [tick], Log.TAG_DELTA_EVENT)
						continue
					
					for event_id: int in input:
						event_set[event_id] = true

				delta_prop_last_tick[prop_id] = co_ticks.ticks
