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

		WyncFlow.wync_handle_net_packet_inputs(wync_ctx, data, pkt.from_peer)
			
		# consume
		co_io.in_packets.remove_at(k)

	WyncFlow.wync_input_props_set_tick_value(wync_ctx)
