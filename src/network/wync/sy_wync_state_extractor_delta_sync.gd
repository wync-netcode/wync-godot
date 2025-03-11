extends System
class_name SyWyncStateExtractorDeltaSync
const label: StringName = StringName("SyWyncStateExtractorDeltaSync")

## This system name isn't very precise TODO: rename
## Collects what events ids must be synced with each client
## Collects what event data must be synced with each client
## NOTE: Maybe the loop order should be Client->Prop cause Spatial Relative Synchronization


func on_process(_entities, _data, _delta: float):
	#wync_reset_events_to_sync(ctx)
	#queue_delta_event_data_to_be_synced_to_peers(ctx)
	pass


# --------------------------------------------------------------------------------
# Service 1: Send all _delta event_ ids to clients
# TODO: For now all clients know about this prop, later we can filter
# This service doesn't write state

static func wync_reset_events_to_sync(ctx: WyncCtx):

	# reset events

	for wync_client_id in range(1, ctx.peers.size()):
		var event_set = ctx.peers_events_to_sync[wync_client_id] as Dictionary
		event_set.clear()


# TODO: Make a separate version only for _event_ids_ different from _inputs any_
# TODO: Make a separate version only for _delta event_ids_
static func wync_prop_event_send_event_ids_to_peer(ctx: WyncCtx, prop_id: int) -> WyncPktInputs:

	# get props: base + auxiliar
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return null
	prop = prop as WyncEntityProp

	# prepare packet

	var pkt_inputs = WyncPktInputs.new()

	for tick in range(ctx.co_ticks.ticks - WyncCtx.INPUT_AMOUNT_TO_SEND, ctx.co_ticks.ticks +1):
		if prop.confirmed_states_tick.get_at(tick) != tick:
			continue
		var input = prop.confirmed_states.get_at(tick)
		if input == null:
			Log.err("we don't have an input for this tick %s" % [tick], Log.TAG_DELTA_EVENT)
			continue
		
		var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
		tick_input_wrap.tick = tick
		
		var copy = WyncUtils.duplicate_any(input)
		if copy == null:
			Log.errc(ctx, "WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_DELTA_EVENT)
		tick_input_wrap.data = copy if copy != null else input
			
		pkt_inputs.inputs.append(tick_input_wrap)

	pkt_inputs.amount = pkt_inputs.inputs.size()
	pkt_inputs.prop_id = prop_id

	return pkt_inputs


# --------------------------------------------------------------------------------
# DEPRECATED
# Service 2: For each peer collect what _delta event data_ they need
# collect what event_ids need their _delta event data_ synced depending on peer
# This service writes state

"""
static func queue_delta_event_data_to_be_synced_to_peers(ctx: WyncCtx):

	var co_ticks = ctx.co_ticks
	var data_size_limit = ctx.out_packets_size_remaining_chars
	var data_size = 0

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
					if aux_prop.confirmed_states_tick.get_at(tick) != tick:
						Log.err("we don't have an input for this tick %s" % [tick], Log.TAG_DELTA_EVENT)
						continue

					var input = aux_prop.confirmed_states.get_at(tick)
					if input is not Array[int]:
						Log.err("we don't have an input for this tick %s" % [tick], Log.TAG_DELTA_EVENT)
						continue

					# necessary space for this whole tick
					var tick_size = 0
					
					for event_id: int in input:

						if WyncDeltaSyncUtils.event_is_healthy(ctx, event_id) != OK:
							# FATAL
							assert(false)

						event_set[event_id] = true
						var event = ctx.events[event_id] as WyncEvent
						var event_size = HashUtils.calculate_object_data_size(event)
						tick_size += event_size

					# size check 
					if ((data_size + tick_size) > data_size_limit):
						break

					# committing
					delta_prop_last_tick[prop_id] = tick
					WyncThrottle.wync_ocuppy_space_towards_packets_data_size_limit(ctx, tick_size)
					data_size += tick_size
"""
