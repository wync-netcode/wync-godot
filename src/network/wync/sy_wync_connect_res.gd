extends System
class_name SyWyncConnectRes
const label: StringName = StringName("SyWyncConnectRes")

## Setup Wync client


func _ready():
	components = [ CoSingleWyncContext.label ]
	super()


func on_process(_entities, _data, _delta: float):
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		Log.err("No single_server", Log.TAG_WYNC_CONNECT)
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	var wync_ctx = single_wync.ctx as WyncCtx
	if not wync_ctx.connected:
		return

	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinReq
		if not data:
			continue

		WyncFlow.wync_handle_pkt_join_req(wync_ctx, data, pkt.from_peer)
			
		# consume
		co_io.in_packets.remove_at(k)
