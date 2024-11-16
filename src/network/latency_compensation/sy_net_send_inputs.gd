extends System
class_name SyNetSendInputs
const label: StringName = StringName("SyNetSendInputs")

## * Sends inputs to server in chunks
## * TODO: Let the server deduce which actor to move based on client


func _ready():
	components = [CoActor.label, CoNetBufferedInputs.label]
	super()
	

func on_process(entities, _data, _delta: float):

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

	for entity: Entity in entities:

		var co_buffered_inputs = entity.get_component(CoNetBufferedInputs.label) as CoNetBufferedInputs
		var co_actor = entity.get_component(CoActor.label) as CoActor

		# prepare packet

		var net_inputs = NetPacketInputs.new()

		for i in range(tick_pred - CoNetBufferedInputs.AMOUNT_TO_SEND, tick_pred +1):
			var tick_local = co_buffered_inputs.get_tick_predicted(i)
			if not tick_local:
				continue
			var input = co_buffered_inputs.get_tick(tick_local)
			if input is not CoActorInput:
				#Log.out(self, "we don't have an input for this tick %s" % [i])
				continue
			var input_copy = input.copy()
			input_copy.tick = i
			net_inputs.inputs.append(input_copy)
			#Log.out(self, "sending inputs move %s (tick_pred %s)" % [input.movement_dir, i])

		net_inputs.amount = net_inputs.inputs.size()
		net_inputs.actor_id = co_actor.id  ## FIXME

		# prepare peer packet and send (queue)

		var pkt = NetPacket.new()
		pkt.to_peer = co_client.server_peer
		pkt.data = net_inputs
		co_io_packets.out_packets.append(pkt)
		return # NOTE: for now only send for the first occurrence
