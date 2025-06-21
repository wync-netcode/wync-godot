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
		ctx.pending_entity_to_spawn_props[entity_id] = [prop_start, prop_end, 0] as Array[int]

		# queue it to user facing variable
		entity_to_spawn = WyncCtx.EntitySpawnEvent.new()
		entity_to_spawn.spawn = true
		entity_to_spawn.already_spawned = false
		entity_to_spawn.entity_id = entity_id
		entity_to_spawn.entity_type_id = entity_type_id
		entity_to_spawn.spawn_data = spawn_data

		ctx.out_queue_spawn_events.push_head(entity_to_spawn)


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
		if ctx.pending_entity_to_spawn_props.has(entity_id):

			assert(ctx.pending_entity_to_spawn_props.erase(entity_id))

			var queue = ctx.out_queue_spawn_events

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
			ctx.out_queue_spawn_events.push_head(entity_to_spawn)


static func wync_get_next_entity_event_spawn(ctx: WyncCtx) -> WyncCtx.EntitySpawnEvent:
	var size = ctx.out_queue_spawn_events.size
	if size <= 0:
		return null

	var event = ctx.out_queue_spawn_events.pop_tail()
	if event is not WyncCtx.EntitySpawnEvent:
		return null

	ctx.next_entity_to_spawn = event
	return event


static func finish_spawning_entity(ctx: WyncCtx, entity_id: int) -> int:

	var entity_to_spawn = ctx.next_entity_to_spawn
	entity_to_spawn.already_spawned = true

	assert(ctx.pending_entity_to_spawn_props.has(entity_id))
	var entity_auth_props: Array[int] = ctx.pending_entity_to_spawn_props[entity_id]
	assert((entity_auth_props[1] - entity_auth_props[0]) == (entity_auth_props[2] - 1))

	ctx.pending_entity_to_spawn_props.erase(entity_id)

	Log.outc(ctx, "spawn, spawned entity %s" % [entity_id])

	# apply dummy props if any

	for prop_id: int in ctx.entity_has_props[entity_id]:
		if not ctx.dummy_props.has(prop_id):
			continue
		
		var dummy_prop = ctx.dummy_props[prop_id] as WyncCtx.DummyProp
		WyncStateStore.prop_save_confirmed_state(ctx, prop_id, dummy_prop.last_tick, dummy_prop.data)

		# clean up

		ctx.dummy_props.erase(prop_id)

	return OK


## Call after finishing spawning entities
static func wync_system_spawned_props_cleanup(ctx: WyncCtx):
	ctx.out_queue_spawn_events.clear()
	#for i in range(ctx.out_pending_entities_to_spawn.size()-1, -1, -1):
		#var entity_to_spawn: WyncCtx.EntitySpawnEvent = ctx.out_pending_entities_to_spawn[i]
		#if entity_to_spawn.already_spawned:
			#ctx.out_pending_entities_to_spawn.remove_at(i)


