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

		wync_handle_pkt_join_req(wync_ctx, data, pkt.from_peer)
			
		# consume
		co_io.in_packets.remove_at(k)


static func wync_handle_pkt_join_req(ctx: WyncCtx, data: Variant, from_peer: int) -> int:

	if data is not WyncPktJoinReq:
		return 1
	data = data as WyncPktJoinReq
	
	# TODO: check it hasn't been setup yet
	# NOTE: the criteria to determine wether a client has a valid prop ownership could be user defined
	# NOTE: wync setup must be ran only once per client
	
	var wync_client_id = WyncUtils.is_peer_registered(ctx, from_peer)
	if wync_client_id != -1:
		Log.out("Client %s already setup in Wync as %s" % [from_peer, wync_client_id], Log.TAG_WYNC_CONNECT)
		return 1
	wync_client_id = WyncUtils.peer_register(ctx, from_peer)
	
	# send confirmation
	
	var packet_data = WyncPktJoinRes.new()
	packet_data.approved = true
	packet_data.wync_client_id = wync_client_id
	
	var packet = NetPacket.new()
	packet.to_peer = from_peer
	packet.data = packet_data
	ctx.out_packets.append(packet)
	
	# NOTE: Maybe move this elsewhere, the client could ask this any time
	# FIXME Harcoded: client 0 -> entity 0 (player)
	packet = make_client_info_packet(ctx, wync_client_id, 0, "input")
	packet.to_peer = from_peer
	ctx.out_packets.append(packet)
	
	packet = make_client_info_packet(ctx, wync_client_id, 0, "events")
	packet.to_peer = from_peer
	ctx.out_packets.append(packet)
	
	# let client own it's global events
	# NOTE: Maybe move this where all channels are defined
	var global_events_entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + wync_client_id
	if WyncUtils.is_entity_tracked(ctx, global_events_entity_id):
		packet = make_client_info_packet(ctx, wync_client_id, global_events_entity_id, "channel_0")
		packet.to_peer = from_peer
		ctx.out_packets.append(packet)
	
	else:
		Log.err("Global Event Entity (id %s) for peer_id %s NOT FOUND" % [global_events_entity_id, wync_client_id], Log.TAG_WYNC_CONNECT)

	return OK
	

static func make_client_info_packet(
	ctx: WyncCtx,
	wync_client_id: int,
	entity_id: int,
	prop_name: String) -> NetPacket:
	
	var prop_id = WyncUtils.entity_get_prop_id(ctx, entity_id, prop_name)
	var packet_data = WyncPacketResClientInfo.new()
	packet_data.entity_id = entity_id
	packet_data.prop_id = prop_id
	
	WyncUtils.prop_set_client_owner(ctx, prop_id, wync_client_id)
	Log.out("assigned (entity %s: prop %s) to client %s" % [packet_data.entity_id, prop_id, wync_client_id], Log.TAG_WYNC_CONNECT)
	
	var packet = NetPacket.new()
	packet.data = packet_data
	return packet
