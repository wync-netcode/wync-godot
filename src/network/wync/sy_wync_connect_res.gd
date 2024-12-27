extends System
class_name SyWyncConnectRes
const label: StringName = StringName("SyWyncConnectRes")

## Setup Wync client


func _ready():
	components = [
		CoSingleWyncContext.label
	]
	super()


func on_process(entities, _data, _delta: float):
	var single_server = ECS.get_singleton_entity(self, "EnSingleServer")
	if not single_server:
		Log.err(self, "No single_client")
		return
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if wync_ctx.connected:
		return
	var co_io = single_server.get_component(CoIOPackets.label) as CoIOPackets
	
	
	for k in range(co_io.in_packets.size()-1, -1, -1):
		var pkt = co_io.in_packets[k] as NetPacket
		var data = pkt.data as WyncPktJoinReq
		if not data:
			continue
			
		# consume
		co_io.in_packets.remove_at(k)
		
		# TODO: check it hasn't been setup yet
		# NOTE: the criteria to determine wether a client has a valid prop ownership could be user defined
		# NOTE: wync setup must be ran only once per client
		
		var wync_client_id = WyncUtils.is_client_registered(wync_ctx, pkt.from_peer)
		if wync_client_id != -1:
			Log.out(self, "Client %s already setup in Wync as %s" % [pkt.from_peer, wync_client_id])
			continue
		wync_client_id = WyncUtils.client_register(wync_ctx, pkt.from_peer)
		
		# send confirmation
		
		var packet_data = WyncPktJoinRes.new()
		packet_data.approved = true
		packet_data.wync_client_id = wync_client_id
		
		var packet = NetPacket.new()
		packet.to_peer = pkt.from_peer
		packet.data = packet_data
		co_io.out_packets.append(packet)
		
		# NOTE: Maybe move this elsewhere, the client could ask this any time
		# FIXME Harcoded: client 0 -> entity 0 (player)
		
		var prop_id = WyncUtils.entity_get_prop_id(wync_ctx, 0, "input")
		packet_data = WyncPacketResClientInfo.new()
		packet_data.entity_id = 0
		packet_data.prop_id = prop_id
		
		WyncUtils.prop_set_client_owner(wync_ctx, prop_id, wync_client_id)
		
		packet = NetPacket.new()
		packet.to_peer = pkt.from_peer
		packet.data = packet_data
		co_io.out_packets.append(packet)
		
		Log.out(self, "assigned (entity %s) prop %s to client %s" % [packet_data.entity_id, prop_id, pkt.from_peer])
