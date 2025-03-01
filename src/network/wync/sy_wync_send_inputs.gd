extends System
class_name SyWyncSendInputs
const label: StringName = StringName("SyWyncSendInputs")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err(self, "Couldn't find singleton EnSingleClient")
		return
	var co_client = en_client.get_component(CoClient.label) as CoClient
	if co_client.server_peer < 0:
		Log.err(self, "No server peer")
		return
	var co_io_packets = en_client.get_component(CoIOPackets.label) as CoIOPackets
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_pred = co_predict_data.target_tick
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	# reset events_id to sync
	wync_ctx.events_to_sync_this_tick.clear()
	
	for prop_id: int in wync_ctx.client_owns_prop[wync_ctx.my_peer_id]:
		
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err(self, "prop %s doesn't exists" % prop_id)
			continue
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		if not input_prop:
			Log.err(self, "not input_prop %s" % prop_id)
			continue
		if input_prop.data_type not in [WyncEntityProp.DATA_TYPE.INPUT,
			WyncEntityProp.DATA_TYPE.EVENT]:
			Log.err(self, "prop %s is not INPUT or EVENT" % prop_id)
			continue
		var buffered_inputs = input_prop.confirmed_states

		# prepare packet

		var net_inputs = NetPacketInputs.new()

		for i in range(tick_pred - CoNetBufferedInputs.AMOUNT_TO_SEND, tick_pred +1):
			var tick_local = co_predict_data.get_tick_predicted(i)
			if not tick_local:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
				continue
			var input = buffered_inputs.get_at(tick_local)
			if input == null:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
				continue
			
			var tick_input_wrap = NetPacketInputs.NetTickDataDecorator.new()
			tick_input_wrap.tick = i
			
			var copy = WyncUtils.duplicate_any(input)
			if copy == null:
				Log.out(self, "WARNING: input data couldn't be duplicated %s" % [input])
			tick_input_wrap.data = copy if copy != null else input
				
			net_inputs.inputs.append(tick_input_wrap)
			
			# compile events ids
			if (input_prop.data_type == WyncEntityProp.DATA_TYPE.EVENT &&
				input is Array):
				input = input as Array
				for event_id in input:
					wync_ctx.events_to_sync_this_tick[event_id] = 0
				

		net_inputs.amount = net_inputs.inputs.size()
		net_inputs.prop_id = prop_id
		#Log.out(self, "INPUT Sending prop %s" % [input_prop.name_id]) 

		# prepare peer packet and send (queue)

		var pkt = NetPacket.new()
		pkt.to_peer = co_client.server_peer
		pkt.data = net_inputs
		co_io_packets.out_packets.append(pkt)
