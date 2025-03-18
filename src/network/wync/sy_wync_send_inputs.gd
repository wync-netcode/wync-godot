extends System
class_name SyWyncSendInputs
const label: StringName = StringName("SyWyncSendInputs")

## * Sends inputs/events in chunks

## TODO: either throttle or commit to the packet
## This system writes state (ctx.peers_events_to_sync) but it's naturally redundant
## So think about it as if it didn't write state
static func wync_client_send_inputs (ctx: WyncCtx):

	var co_predict_data = ctx.co_predict_data
	var tick_pred = co_predict_data.target_tick

	if !ctx.connected:
		return
	
	# reset events_id to sync
	var event_set = ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID] as Dictionary
	event_set.clear()
	
	for prop_id in ctx.type_input_event__owned_prop_ids:
		var input_prop := WyncUtils.get_prop_unsafe(ctx, prop_id)

		# prepare packet
		# NOTE: Data size limit could be imposed at this level too

		var pkt_inputs = WyncPktInputs.new()

		for i in range(tick_pred - WyncCtx.INPUT_AMOUNT_TO_SEND, tick_pred +1):
			if input_prop.confirmed_states_tick.get_at(i) != i:
				#Log.outc(ctx, "we don't have an input for this tick %s" % [i])
				continue
			var input = input_prop.confirmed_states.get_at(i)
			if input == null:
				# TODO: Implement input duplication on frame skip
				#Log.outc(ctx, "we don't have an input for this tick %s" % [i])
				continue
			
			var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
			tick_input_wrap.tick = i
			
			var copy = WyncUtils.duplicate_any(input)
			if copy == null:
				Log.out("WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_INPUT_BUFFER)
			tick_input_wrap.data = copy if copy != null else input
				
			pkt_inputs.inputs.append(tick_input_wrap)
			
			# compile events ids
			if (input_prop.prop_type == WyncEntityProp.PROP_TYPE.EVENT &&
				input is Array):
				input = input as Array
				for event_id: int in input:
					event_set[event_id] = true

		pkt_inputs.amount = pkt_inputs.inputs.size()
		pkt_inputs.prop_id = prop_id
		#Log.out(self, "INPUT Sending prop %s" % [input_prop.name_id]) 
		#if input_prop.prop_type == WyncEntityProp.prop_type.EVENT:
			#Log.outc(ctx, "tic(%s) setted | sending prop (%s) (%s) " % [tick_pred, prop_id, pkt_inputs.inputs[0].data])

		# prepare peer packet and send (queue)

		var result = WyncFlow.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_INPUTS, pkt_inputs)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			var err = WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.UNRELIABLE, false)
			if err != OK: # Out of space
				break

	#Log.outc(ctx, "debugevents | TOTAL events to sync %s" % [event_set.keys()])
