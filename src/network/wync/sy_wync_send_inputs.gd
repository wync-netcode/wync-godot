extends System
class_name SyWyncSendInputs
const label: StringName = StringName("SyWyncSendInputs")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func _ready():
	components = []
	super()
	

func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err(self, "Couldn't find singleton EnSingleClient")
		return
	var co_client = en_client.get_component(CoClient.label) as CoClient
	var co_io_packets = en_client.get_component(CoIOPackets.label) as CoIOPackets
	if co_client.server_peer < 0:
		Log.err(self, "No server peer")
		return
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	var tick_pred = co_predict_data.target_tick
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		return
	
	for prop_id: int in wync_ctx.client_owns_prop[wync_ctx.my_client_id]:
		
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err(self, "prop %s doesn't exists" % prop_id)
			continue
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		if not input_prop:
			Log.err(self, "not input_prop %s" % prop_id)
			continue
		if input_prop.data_type != WyncEntityProp.DATA_TYPE.INPUT:
			Log.err(self, "prop %s is not data_type.INPUT" % prop_id)
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
			if input is not CoActorInput:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
				continue
			var input_copy = input.copy()
			input_copy.tick = i
			net_inputs.inputs.append(input_copy)
			#Log.out(self, "sending inputs move %s (tick_pred %s)" % [input.movement_dir, i])

		net_inputs.amount = net_inputs.inputs.size()
		net_inputs.prop_id = prop_id

		# prepare peer packet and send (queue)

		var pkt = NetPacket.new()
		pkt.to_peer = co_client.server_peer
		pkt.data = net_inputs
		co_io_packets.out_packets.append(pkt)
		return # NOTE: for now only send for the first occurrence
