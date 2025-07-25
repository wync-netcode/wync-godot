class_name WyncSpawn


static func wync_handle_pkt_spawn(ctx: WyncCtx, data: Variant):

	if data is not WyncPktSpawn:
		return 1
	data = data as WyncPktSpawn

	var entity_to_spawn: WyncCtx.EntitySpawnEvent = null
	for i: int in range(data.entity_amount):

		var entity_id = data.entity_ids[i]
		var entity_type_id = data.entity_type_ids[i]
		var prop_start = data.entity_prop_id_start[i]
		var prop_end = data.entity_prop_id_end[i]
		var spawn_data = data.entity_spawn_data[i]

		# "flag" it
		ctx.co_spawn.pending_entity_to_spawn_props[entity_id] = [prop_start, prop_end, 0] as Array[int]

		# queue it to user facing variable
		entity_to_spawn = WyncCtx.EntitySpawnEvent.new()
		entity_to_spawn.spawn = true
		entity_to_spawn.already_spawned = false
		entity_to_spawn.entity_id = entity_id
		entity_to_spawn.entity_type_id = entity_type_id
		entity_to_spawn.spawn_data = spawn_data

		ctx.co_spawn.out_queue_spawn_events.push_head(entity_to_spawn)


static func wync_handle_pkt_despawn(ctx: WyncCtx, data: Variant):

	if data is not WyncPktDespawn:
		return 1
	data = data as WyncPktDespawn

	var entity_to_spawn: WyncCtx.EntitySpawnEvent = null

	for i: int in range(data.entity_amount):

		var entity_id = data.entity_ids[i]

		# TODO: untrack only if it exists already
		# NOTE: There might be a bug where we untrack an entity that needed to be respawned
		WyncTrack.untrack_entity(ctx, entity_id)

		## remove from spawn list if found
		if ctx.co_spawn.pending_entity_to_spawn_props.has(entity_id):

			assert(ctx.co_spawn.pending_entity_to_spawn_props.erase(entity_id))

			var queue = ctx.co_spawn.out_queue_spawn_events

			for k: int in range(queue.size):
				var item: WyncCtx.EntitySpawnEvent = queue.get_relative_to_tail(k)
				assert(item != null)

				if item.entity_id == entity_id && item.spawn == true:
					assert(queue.remove_relative_to_tail(k) == OK)
					break

		else:

			entity_to_spawn = WyncCtx.EntitySpawnEvent.new()
			entity_to_spawn.spawn = false
			entity_to_spawn.entity_id = entity_id
			ctx.co_spawn.out_queue_spawn_events.push_head(entity_to_spawn)


static func wync_get_next_entity_event_spawn(ctx: WyncCtx) -> WyncCtx.EntitySpawnEvent:
	var size = ctx.co_spawn.out_queue_spawn_events.size
	if size <= 0:
		return null

	var event = ctx.co_spawn.out_queue_spawn_events.pop_tail()
	if event is not WyncCtx.EntitySpawnEvent:
		return null

	ctx.co_spawn.next_entity_to_spawn = event
	return event


static func finish_spawning_entity(ctx: WyncCtx, entity_id: int) -> int:

	var entity_to_spawn = ctx.co_spawn.next_entity_to_spawn
	entity_to_spawn.already_spawned = true

	assert(ctx.co_spawn.pending_entity_to_spawn_props.has(entity_id))
	var entity_auth_props: Array[int] = ctx.co_spawn.pending_entity_to_spawn_props[entity_id]
	assert((entity_auth_props[1] - entity_auth_props[0]) == (entity_auth_props[2] - 1))

	ctx.co_spawn.pending_entity_to_spawn_props.erase(entity_id)

	Log.outc(ctx, "spawn, spawned entity %s" % [entity_id])

	# apply dummy props if any

	for prop_id: int in ctx.co_track.entity_has_props[entity_id]:
		if not ctx.co_dummy.dummy_props.has(prop_id):
			continue
		
		var dummy_prop = ctx.co_dummy.dummy_props[prop_id] as WyncCtx.DummyProp
		WyncStateStore.prop_save_confirmed_state(ctx, prop_id, dummy_prop.last_tick, dummy_prop.data)

		# clean up

		ctx.co_dummy.dummy_props.erase(prop_id)

	return OK


## Call after finishing spawning entities
static func wync_system_spawned_props_cleanup(ctx: WyncCtx):
	ctx.co_spawn.out_queue_spawn_events.clear()


## TODO: fix all these comments
## @argument commit: bool. Pass True if you're gonna send this message through the network,
## so that Wync can assume it will arrive
## This system is network throttled
## Note: as it is the first clients have priority until the out buffer fills
static func wync_system_send_entities_to_spawn(ctx: WyncCtx, _commit: bool = true) -> int:
	var data_used = 0
	var ids_to_spawn: Dictionary = {} # : Set<int>

	for client_id in range(1, ctx.common.peers.size()):

		var new_entities_set = ctx.co_throttling.clients_sees_new_entities[client_id] as Dictionary
		var current_entities_set = ctx.co_throttling.clients_sees_entities[client_id] as Dictionary
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
			packet.entity_type_ids[i] = ctx.co_track.entity_is_of_type[entity_id]
			var entity_prop_ids = ctx.co_track.entity_has_props[entity_id]
			assert(entity_prop_ids.size() > 0)
			packet.entity_prop_id_start[i] = entity_prop_ids[0]
			packet.entity_prop_id_end[i] = entity_prop_ids[entity_prop_ids.size() -1]

			if ctx.co_spawn.entity_spawn_data.has(entity_id):
				packet.entity_spawn_data[i] = WyncMisc.duplicate_any(ctx.co_spawn.entity_spawn_data[entity_id])

			# commit / confirm as _client can see it_

			_wync_confirm_client_can_see_entity(ctx, client_id, entity_id)

			data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_SPAWN)
			if (data_used >= ctx.common.out_packets_size_remaining_chars):
				break

		if ((i + 1) != entity_amount):
			packet.resize(i + 1)

		# queue 
		var res = WyncPacketUtil.wync_wrap_packet_out(ctx, client_id, WyncPacket.WYNC_PKT_SPAWN, packet)
		if res[0] == OK:
			var pkt_out = res[1] as WyncPacketOut
			WyncPacketUtil.wync_try_to_queue_out_packet(ctx, pkt_out, WyncCtx.RELIABLE, true)

		if (data_used >= ctx.common.out_packets_size_remaining_chars):
			break
		
	return OK


# This system is not throttled
static func wync_system_send_entities_to_despawn(ctx: WyncCtx, _commit: bool = true) -> int:

	for client_id in range(1, ctx.common.peers.size()):

		var current_entities_set = ctx.co_throttling.clients_sees_entities[client_id] as Dictionary
		var entity_id_list: Array[int] = []
		var entity_amount = 0

		for entity_id: int in ctx.co_spawn.despawned_entity_ids:
			if current_entities_set.has(entity_id):
				entity_id_list.append(entity_id)
				entity_amount += 1

				# ATTENTION: Removing entity here
				current_entities_set.erase(entity_id)

				Log.outc(ctx, "I: spawn, confirmed: client %s no longer sees entity %s" % [
					client_id, entity_id])

		if entity_amount == 0:
			continue

		var packet = WyncPktDespawn.new(entity_amount)
		for i in range(entity_amount):
			packet.entity_ids[i] = entity_id_list[i]

		# queue 
		var res = WyncPacketUtil.wync_wrap_packet_out(ctx, client_id, WyncPacket.WYNC_PKT_DESPAWN, packet)
		assert(res[0] == OK)
		var pkt_out = res[1] as WyncPacketOut
		WyncPacketUtil.wync_try_to_queue_out_packet(ctx, pkt_out, WyncCtx.RELIABLE, true)

	ctx.co_spawn.despawned_entity_ids.clear()

	return OK


## TODO: this function is too similar to wync_add_local_existing_entity
## Removes an entity from clients_sees_new_entities
static func _wync_confirm_client_can_see_entity(ctx: WyncCtx, client_id: int, entity_id: int) -> void:

	var entity_set = ctx.co_throttling.clients_sees_entities[client_id]
	entity_set[entity_id] = true

	for prop_id: int in ctx.co_track.entity_has_props[entity_id]:
		var prop = WyncTrack.get_prop(ctx, prop_id)
		if prop == null:
			Log.errc(ctx, "Couldn't find prop(%s) in entity(%s)" % [prop_id, entity_id])
			continue
		prop = prop as WyncProp

		if prop.relative_syncable:
			var delta_prop_last_tick = ctx.co_track.client_has_relative_prop_has_last_tick[client_id] as Dictionary
			delta_prop_last_tick[prop_id] = -1

	# remove from new entities
	var new_entity_set = ctx.co_throttling.clients_sees_new_entities[client_id] as Dictionary
	new_entity_set.erase(entity_id)

	Log.outc(ctx, "spawn, confirmed: client %s can now see entity %s" % [
		client_id, entity_id])
