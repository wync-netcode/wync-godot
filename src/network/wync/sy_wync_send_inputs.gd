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
	var wync_ctx = single_wync.ctx as WyncCtx
	var co_predict_data = wync_ctx.co_predict_data
	var tick_pred = co_predict_data.target_tick

	if !wync_ctx.connected:
		return
	
	# reset events_id to sync
	wync_ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID].clear()
	
	for prop_id: int in wync_ctx.client_owns_prop[wync_ctx.my_peer_id]:
		
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		if not input_prop:
			Log.err("not input_prop %s" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		if input_prop.data_type not in [WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			Log.err("prop %s is not INPUT or EVENT" % prop_id, Log.TAG_INPUT_BUFFER)
			continue
		var buffered_inputs = input_prop.confirmed_states

		# prepare packet

		var pkt_inputs = WyncPktInputs.new()

		for i in range(tick_pred - CoNetBufferedInputs.AMOUNT_TO_SEND, tick_pred +1):
			var tick_local = co_predict_data.get_tick_predicted(i)
			if not tick_local:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
				continue
			var input = buffered_inputs.get_at(tick_local)
			if input == null:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
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
					var event_set = wync_ctx.peers_events_to_sync[WyncCtx.SERVER_PEER_ID] as Dictionary
					event_set[event_id] = true
				

		pkt_inputs.amount = pkt_inputs.inputs.size()
		pkt_inputs.prop_id = prop_id
		#Log.out(self, "INPUT Sending prop %s" % [input_prop.name_id]) 

		# prepare peer packet and send (queue)

		var result = WyncFlow.wync_wrap_packet_out(wync_ctx, WyncCtx.SERVER_PEER_ID, WyncPacket.WYNC_PKT_INPUTS, pkt_inputs)
		if result[0] == OK:
			var packet_out = result[1] as WyncPacketOut
			wync_ctx.out_packets.append(packet_out)
