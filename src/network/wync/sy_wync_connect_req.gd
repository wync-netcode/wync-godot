extends System
class_name SyWyncConnectReq
const label: StringName = StringName("SyWyncConnectReq")

## Setup Wync client


func _ready():
	components = [
		CoSingleWyncContext.label
	]
	super()


func on_process(_entities, _data, _delta: float):
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not single_client:
		Log.err("No single_client", Log.TAG_WYNC_CONNECT)
		return
	var co_client = single_client.get_component(CoClient.label) as CoClient
	if co_client.state != CoClient.STATE.CONNECTED:
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if wync_ctx.connected:
		return
	var co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets

	# might want to move this elsewhere

	WyncFlow.wync_try_to_connect(wync_ctx)
	
	# check for response packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinRes
		if not data:
			continue

		#WyncFlow.wync_handle_pkt_join_res(wync_ctx, data)

		# consume
		co_io.in_packets.remove_at(k)
