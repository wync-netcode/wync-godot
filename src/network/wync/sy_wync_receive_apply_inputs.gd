extends System
class_name SyWyncReceiveApplyInputs
const label: StringName = StringName("SyWyncReceiveApplyInputs")

## * Buffers the inputs per tick


func _ready():
	components = [CoActor.label, CoActorInput.label, CoActorRegisteredFlag.label, CoNetBufferedInputs.label]
	super()
	

func on_process(_entities, _data, _delta: float, node_root: Node = null):
	
	var node_self = self if node_root == null else node_root
	var en_server = ECS.get_singleton_entity(node_self, "EnSingleServer")
	if not en_server:
		Log.err("Couldn't find singleton EnSingleServer", Log.TAG_INPUT_RECEIVE)
		return
	var co_io = en_server.get_component(CoIOPackets.label) as CoIOPackets
	var single_wync = ECS.get_singleton_component(node_self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	# save all inputs to props

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as NetPacketInputs
		if not data:
			continue

		wync_handle_net_packet_inputs(wync_ctx, data, pkt.from_peer)
			
		# consume
		co_io.in_packets.remove_at(k)

	wync_input_props_set_tick_value(wync_ctx)


static func wync_handle_net_packet_inputs(ctx: WyncCtx, data: Variant, from_peer: int) -> int:

	if data is not NetPacketInputs:
		return 1
	data = data as NetPacketInputs

	# client and prop exists
	var client_id = WyncUtils.is_peer_registered(ctx, from_peer)
	if client_id < 0:
		Log.err("client %s is not registered" % client_id, Log.TAG_INPUT_RECEIVE)
		return 2
	var prop_id = data.prop_id
	if not WyncUtils.prop_exists(ctx, prop_id):
		Log.err("prop %s doesn't exists" % prop_id, Log.TAG_INPUT_RECEIVE)
		return 3
	
	# check client has ownership over this prop
	var client_owns_prop = false
	for i_prop_id in ctx.client_owns_prop[client_id]:
		if i_prop_id == prop_id:
			client_owns_prop = true
	if not client_owns_prop:
		return 4
	
	var input_prop = ctx.props[prop_id] as WyncEntityProp
	
	# save the input in the prop before simulation
	# TODO: data.copy is not standarized
	
	for input: NetPacketInputs.NetTickDataDecorator in data.inputs:
		var copy = WyncUtils.duplicate_any(input.data)
		if copy == null:
			Log.out("WARNING: input data can't be duplicated %s" % [input.data], Log.TAG_INPUT_RECEIVE)
		var to_insert = copy if copy != null else input.data
		
		input_prop.confirmed_states.insert_at(input.tick, to_insert)

	return OK


# apply inputs / events to props
# TODO: Better to separate receive/apply logic
# NOTE: could this be merged with SyWyncLatestValue?

static func wync_input_props_set_tick_value (ctx: WyncCtx) -> int:
		
	for client_id in range(1, ctx.peers.size()):
		for prop_id in ctx.client_owns_prop[client_id]:
			if not WyncUtils.prop_exists(ctx, prop_id):
				continue
			var prop = ctx.props[prop_id] as WyncEntityProp
			if not prop:
				continue
			if (prop.data_type != WyncEntityProp.DATA_TYPE.INPUT &&
				prop.data_type != WyncEntityProp.DATA_TYPE.EVENT):
				continue
		
			# FIXME: check the tick with a wrapper/decorator class for inputs to avoid using old values
			var input = prop.confirmed_states.get_at(ctx.co_ticks.ticks)
			if input == null:
				continue
			prop.setter.call(input)
			#Log.out(self, "input is %s,%s" % [input.movement_dir.x, input.movement_dir.y])

	return OK

