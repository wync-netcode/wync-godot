extends System
class_name SyWyncSendInputs
const label: StringName = StringName("SyWyncSendInputs")

## * Sends inputs/events in chunks


func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err("Couldn't find singleton EnSingleClient", Log.TAG_INPUT_BUFFER)
		return
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	wync_client_send_inputs (ctx)
	

## TODO: either throttle or commit to the packet
## This system writes state (ctx.peers_events_to_sync) but it's naturally redundant
## So think about it as if it didn't write state
static func wync_client_send_inputs (ctx: WyncCtx):

	var co_predict_data = ctx.co_predict_data
	var tick_pred = co_predict_data.target_tick

	if !ctx.connected:
		return
	
	# reset events_id to sync
	ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID].clear()
	
	for prop_id: int in ctx.client_owns_prop[ctx.my_peer_id]:
		
		if not WyncUtils.prop_exists(ctx, prop_id):
			Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var input_prop := WyncUtils.get_prop(ctx, prop_id)
		if input_prop == null:
			Log.err("not input_prop %s" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		if input_prop.data_type not in [WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			Log.err("prop %s is not INPUT or EVENT" % prop_id, Log.TAG_INPUT_BUFFER)
			continue

		# prepare packet
		# NOTE: Data size limit could be imposed at this level too

		var pkt_inputs = WyncPktInputs.new()

		for i in range(tick_pred - CoNetBufferedInputs.AMOUNT_TO_SEND, tick_pred +1):
			if input_prop.confirmed_states_tick.get_at(i) != i:
				Log.outc(ctx, "we don't have an input for this tick %s" % [i])
				continue
			var input = input_prop.confirmed_states.get_at(i)
			if input == null:
				# TODO: Implement input duplication on frame skip
				Log.outc(ctx, "we don't have an input for this tick %s" % [i])
				continue
			
			var tick_input_wrap = WyncPktInputs.NetTickDataDecorator.new()
			tick_input_wrap.tick = i
			
			var copy = WyncUtils.duplicate_any(input)
			if copy == null:
				Log.out("WARNING: input data couldn't be duplicated %s" % [input], Log.TAG_INPUT_BUFFER)
			tick_input_wrap.data = copy if copy != null else input
				
			pkt_inputs.inputs.append(tick_input_wrap)
			
			# compile events ids
			if (input_prop.data_type == WyncEntityProp.DATA_TYPE.EVENT &&
				input is Array):
				input = input as Array
				for event_id: int in input:
					var event_set = ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID] as Dictionary
					event_set[event_id] = true
				

		pkt_inputs.amount = pkt_inputs.inputs.size()
		pkt_inputs.prop_id = prop_id
		#Log.out(self, "INPUT Sending prop %s" % [input_prop.name_id]) 
		#if input_prop.data_type == WyncEntityProp.DATA_TYPE.EVENT:
			#Log.outc(ctx, "tic(%s) setted | sending prop (%s) (%s) " % [tick_pred, prop_id, pkt_inputs.inputs[0].data])

		# prepare peer packet and send (queue)

		var result = WyncFlow.wync_wrap_packet_out(ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_INPUTS, pkt_inputs)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			var err = WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, false)
			if err != OK: # Out of space
				break
