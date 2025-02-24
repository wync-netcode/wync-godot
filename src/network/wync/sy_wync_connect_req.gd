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

	wync_try_to_connect(wync_ctx)
	
	# check for response packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinRes
		if not data:
			continue

		wync_handle_pkt_join_res(wync_ctx, data)

		# consume
		co_io.in_packets.remove_at(k)


static func wync_try_to_connect(ctx: WyncCtx) -> int:

	# try get server nete_peer_id
	var server_nete_peer_id = WyncUtils.get_nete_peer_id_from_wync_peer_id(ctx, WyncCtx.SERVER_PEER_ID)
	if server_nete_peer_id == -1:
		return 1

	# send connect req packet
	# TODO: Move this elsewhere
	
	var packet_data = WyncPktJoinReq.new()
	var packet = NetPacket.new()
	packet.to_peer = server_nete_peer_id
	packet.data = packet_data
	ctx.out_packets.append(packet)
	return OK


static func wync_handle_pkt_join_res(ctx: WyncCtx, data: Variant) -> int:

	if data is not WyncPktJoinRes:
		return 1
	data = data as WyncPktJoinRes
	
	if not data.approved:
		Log.err("Connection DENIED for client(%s) (me)" % [ctx.my_nete_peer_id], Log.TAG_WYNC_CONNECT)
		return 2
		
	# setup client stuff
	# NOTE: Move this elsewhere?
		
	ctx.connected = true
	ctx.my_peer_id = data.wync_client_id
	WyncUtils.client_setup_my_client(ctx, data.wync_client_id)

	Log.out("client nete_peer_id(%s) connected as wync_peer_id(%s)" % [ctx.my_nete_peer_id, ctx.my_peer_id], Log.TAG_WYNC_CONNECT)
	return OK

