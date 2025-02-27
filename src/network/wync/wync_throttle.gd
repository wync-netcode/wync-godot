class_name WyncThrottle

# Systems
# ----------------------------------------------------------------------


## @argument commit: bool. Pass True if you're gonna send this message through the network,
## so that Wync can assume it will arrive
static func wync_system_send_entities_to_spawn(ctx: WyncCtx, _commit: bool = true) -> int:
	var ids_to_spawn: Dictionary = {} # : Set<int>

	for client_id in range(1, ctx.peers.size()):

		var new_entities_set = ctx.clients_sees_new_entities[client_id] as Dictionary
		var current_entities_set = ctx.clients_sees_entities[client_id] as Dictionary
		ids_to_spawn.clear()

		# compile ids to sync
		for entity_id in new_entities_set.keys():

			# check it isn't already in current_entities_set
			if current_entities_set.has(entity_id):
				continue

			ids_to_spawn[entity_id] = true

		# generate packets and add each new entity to spawn

		var entity_amount = ids_to_spawn.keys().size()
		if entity_amount <= 0:
			continue

		var packet = WyncPktSpawn.new(entity_amount)
		var i = -1

		for entity_id in ids_to_spawn.keys():
			i += 1

			packet.entity_ids[i] = entity_id
			packet.entity_type_ids[i] = 999 # TODO: Need to create entity_types !!!

			# commit / confirm as _client can see it_

			wync_confirm_client_can_see_entity(ctx, client_id, entity_id)

		# queue 
		var res = WyncFlow.wync_wrap_packet_out(ctx, client_id, WyncPacket.WYNC_PKT_SPAWN, packet)
		if res[0] == OK:
			var pkt_out = res[1] as WyncPacketOut
			ctx.out_packets.append(pkt_out)
		
	return OK


static func wync_confirm_client_can_see_entity(ctx: WyncCtx, client_id: int, entity_id: int):

	var entity_set = ctx.clients_sees_entities[client_id]
	entity_set[entity_id] = true

	for prop_id: int in ctx.entity_has_props[entity_id]:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			Log.err("Couldn't find prop(%s) in entity(%s)" % [prop_id, entity_id])
			continue
		prop = prop as WyncEntityProp

		if prop.relative_syncable:
			var delta_prop_last_tick = ctx.client_has_relative_prop_has_last_tick[client_id] as Dictionary
			delta_prop_last_tick[prop_id] = -1

	# remove from new entities
	var new_entity_set = ctx.clients_sees_new_entities[client_id] as Dictionary
	new_entity_set.erase(entity_id)


# Utils
# ----------------------------------------------------------------------


static func wync_client_now_can_see_entity(ctx: WyncCtx, client_id: int, entity_id: int) -> int:
	# entity exists
	if not WyncUtils.is_entity_tracked(ctx, entity_id):
		Log.err("entity (%s) isn't tracked", Log.TAG_THROTTLE)
		return 1

	# already viewed
	if ctx.clients_sees_entities[client_id].has(entity_id):
		return OK

	# add
	var entity_set = ctx.clients_sees_new_entities[client_id] as Dictionary
	entity_set[entity_id] = true

	return OK


static func wync_client_no_longer_sees_entity(ctx: WyncCtx, client_id: int, entity_id: int) -> int:
	# entity exists
	if not WyncUtils.is_entity_tracked(ctx, entity_id):
		Log.err("entity (%s) isn't tracked", Log.TAG_THROTTLE)
		return 1

	# add
	var entity_set = ctx.clients_no_longer_sees_entities[client_id] as Dictionary
	entity_set[entity_id] = true

	return OK


static func _wync_confirm_client_entity_visibility \
		(ctx: WyncCtx, client_id: int, entity_id: int, visible: bool):
	
	var entity_set = ctx.clients_no_longer_sees_entities[client_id] as Dictionary

	if visible:
		entity_set[entity_id] = true
	else:
		entity_set.erase(entity_id)
	
	
## Superseeded? All new entities can be reported with wync_client_now_can_see_entity
## (server only) Use it to report dynamically spawned entities 
## It will generate WyncPktSpawn for all clients that can see it
#static func wync_spawn_new_entity (ctx: WyncCtx, entity_id: int, entity_type_id: int):
	#pass


## (server only)
## * Use it after setting up an entity and it's props
## * Use it to add entities that already exist on the server & client
## * Useful for map provided entities.
## Make sure to reserve some of your _game entity ids_ for static entities
## * Once a peer connects, make sure to setup all map _entity ids_ for him.
## * WARNING: entity_id must be the same on server & client
## * It will prevent the generation of a Spawn packet for that client
## because it assumes the client already has it.

static func wync_add_local_existing_entity \
		(ctx: WyncCtx, client_id: int, entity_id: int):

	if WyncUtils.is_client(ctx):
		return
	if client_id == WyncCtx.SERVER_PEER_ID:
		return

	var entity_set = ctx.clients_sees_entities[client_id]
	entity_set[entity_id] = true

	# remove from new entities

	var new_entity_set = ctx.clients_sees_new_entities[client_id] as Dictionary
	new_entity_set.erase(entity_id)
