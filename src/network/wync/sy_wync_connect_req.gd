extends System
class_name SyWyncConnectReq
const label: StringName = StringName("SyWyncConnectReq")

## Setup Wync client


func _ready():
	components = [
		CoSingleWyncContext.label
	]
	super()


func on_process(entities, _data, _delta: float):
	var single_client = ECS.get_singleton_entity(self, "EnSingleClient")
	if not single_client:
		Log.err(self, "No single_client")
		return
	var co_client = single_client.get_component(CoClient.label) as CoClient
	if co_client.state != CoClient.STATE.CONNECTED:
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if wync_ctx.connected:
		return
	var co_io = single_client.get_component(CoIOPackets.label) as CoIOPackets

	# send connect req packet
	
	var packet_data = WyncPktJoinReq.new()
	var packet = NetPacket.new()
	packet.to_peer = co_client.server_peer
	packet.data = packet_data
	co_io.out_packets.append(packet)
	
	# check for response packets

	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinRes
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
		if not data.approved:
			Log.err(self, "Connection DENIED for peer %s" % [co_io.peer_id])
			continue
			
		wync_ctx.connected = true
		wync_ctx.my_client_id = data.wync_client_id
		WyncUtils.client_setup_my_client(wync_ctx, data.wync_client_id)

		Log.out(self, "client wync %s connected" % [co_io.peer_id])
