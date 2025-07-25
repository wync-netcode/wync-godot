class_name WyncInput ## or WyncClientAuthority



## @returns int:
## * -1 if it belongs to noone (defaults to server)
## * can't return 0
## * returns > 0 (peer_id) if it belongs to a client
static func prop_get_peer_owner(ctx: WyncCtx, prop_id: int) -> int:
	for peer_id in range(1, ctx.common.max_peers):
		if not ctx.co_clientauth.client_owns_prop.has(peer_id):
			continue
		if (ctx.co_clientauth.client_owns_prop[peer_id] as Array).has(prop_id):
			return peer_id
	return -1


static func prop_set_client_owner(ctx: WyncCtx, prop_id: int, client_id: int) -> bool:
	# NOTE: maybe don't check because this prop could be synced later
	#if not prop_exists(ctx, prop_id):
		#return false
	if not ctx.co_clientauth.client_owns_prop.has(client_id):
		ctx.co_clientauth.client_owns_prop[client_id] = []
	ctx.co_clientauth.client_owns_prop[client_id].append(prop_id)

	ctx.co_clientauth.client_ownership_updated = true
	return true


## Server only
## Sends data
static func wync_system_sync_client_ownership(ctx: WyncCtx):
	if not ctx.co_clientauth.client_ownership_updated:
		return
	ctx.co_clientauth.client_ownership_updated = false

	# update all clients about their prop ownership

	for wync_client_id in range(1, ctx.common.peers.size()):
		# TODO: Check peer health / is connected
		for prop_id: int in ctx.co_clientauth.client_owns_prop[wync_client_id] as Array[int]:

			var packet = WyncPktResClientInfo.new()
			packet.prop_id = prop_id
			packet.peer_id = wync_client_id

			var result = WyncPacketUtil.wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				WyncPacketUtil.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)
