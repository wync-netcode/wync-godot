extends System
class_name SyWyncReceiveClientInfo
const label: StringName = StringName("SyWyncReceiveClientInfo")

# TODO: This preferable would be in process


func _ready():
	components = []
	super()
	

func on_process(_entities, _data, _delta: float):

	var en_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not en_client:
		Log.err("Couldn't find singleton EnSingleClient", Log.TAG_WYNC_PEER_SETUP)
		return
	var co_io = en_client.get_component(CoIOPackets.label) as CoIOPackets
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected || wync_ctx.my_peer_id < 0:
		return

	# save tick data from packets
	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPacketResClientInfo
		if not data:
			continue
		
		WyncFlow.wync_handle_packet_res_client_info(wync_ctx, data)

		# consume
		co_io.in_packets.remove_at(k)
