extends System
class_name SyWyncReceiveApplyInputs
const label: StringName = StringName("SyWyncReceiveApplyInputs")

## * Buffers the inputs per tick


func _ready():
	components = [CoActor.label, CoActorInput.label, CoActorRegisteredFlag.label, CoNetBufferedInputs.label]
	super()
	

func on_process(_entities, _data, _delta: float):

	var en_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not en_server:
		Log.err(self, "Couldn't find singleton EnSingleServer")
		return
	var co_io = en_server.get_component(CoIOPackets.label) as CoIOPackets
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# save all inputs to props

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as NetPacketInputs
		if not data:
			continue

		# client and prop exists
		var client_id = WyncUtils.is_peer_registered(wync_ctx, pkt.from_peer)
		if client_id < 0:
			Log.err(self, "client %s is not registered" % client_id)
			continue
		var prop_id = data.prop_id
		if not WyncUtils.prop_exists(wync_ctx, prop_id):
			Log.err(self, "prop %s doesn't exists" % prop_id)
			continue
		
		# check client has ownership over this prop
		var client_owns_prop = false
		for i_prop_id in wync_ctx.client_owns_prop[client_id]:
			if i_prop_id == prop_id:
				client_owns_prop = true
		if not client_owns_prop:
			continue
		
		var input_prop = wync_ctx.props[prop_id] as WyncEntityProp
		
		# save the input in the prop before simulation
		# TODO: data.copy is not standarized
		
		for input: NetPacketInputs.NetTickDataDecorator in data.inputs:
			var copy = WyncUtils.duplicate_any(input.data)
			if copy == null:
				Log.out(self, "WARNING: input data can't be duplicated %s" % [input.data])
			var to_insert = copy if copy != null else input.data
			
			input_prop.confirmed_states.insert_at(input.tick, to_insert)

	# apply inputs / events to props
	# TODO: Better to separate receive/apply logic
		
	for client_id in range(1, wync_ctx.peers.size()):
		for prop_id in wync_ctx.client_owns_prop[client_id]:
			if not WyncUtils.prop_exists(wync_ctx, prop_id):
				continue
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			if not prop:
				continue
			if (prop.data_type != WyncEntityProp.DATA_TYPE.INPUT &&
				prop.data_type != WyncEntityProp.DATA_TYPE.EVENT):
				continue
		
			# FIXME: check the tick with a wrapper/decorator class for inputs
			var input = prop.confirmed_states.get_at(co_ticks.ticks)
			if input == null:
				continue
			prop.setter.call(input)
			#Log.out(self, "input is %s,%s" % [input.movement_dir.x, input.movement_dir.y])
