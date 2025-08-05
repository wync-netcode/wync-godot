class_name WyncThrottle
## Functions related to Throttling and client relative syncronization


# TODO: rename
static func _wync_remove_entity_from_sync_queue(ctx: WyncCtx, peer_id: int, entity_id: int):
	var synced_last_time = ctx.co_throttling.entities_synced_last_time[peer_id] as Dictionary
	synced_last_time[entity_id] = true

	var entity_queue := ctx.co_throttling.queue_clients_entities_to_sync[peer_id] as FIFORing
	var saved_entity_id = entity_queue.pop_tail()

	#Log.outc(ctx, "deb5 marking entity as already synced %s" % [entity_id], Log.TAG_SYNC_QUEUE)
	#Log.outc(ctx, "deb5 synced_last_time is %s" % [synced_last_time.keys()], Log.TAG_SYNC_QUEUE)

	# FIXME
	assert(saved_entity_id == entity_id)


# Just appends entity_id's into the queue 

static func wync_system_fill_entity_sync_queue(ctx: WyncCtx):

	for client_id: int in range(1, ctx.common.peers.size()):

		var entity_queue := ctx.co_throttling.queue_clients_entities_to_sync[client_id] as FIFORing
		var synced_last_time := ctx.co_throttling.entities_synced_last_time[client_id] as Dictionary
		var everything_fitted = true

		for entity_id_key in ctx.co_throttling.clients_sees_entities[client_id].keys():

			# Note. A check to only sync on value change shouln't be here.
			# Instead, check individual props not the whole entity.

			# Note. No need to check if entity is tracked. On entity removal
			# the removed entity_id will be removed from all queues / lists / etc.

			if not synced_last_time.has(entity_id_key) && not entity_queue.has_item(entity_id_key):
				var err = entity_queue.push_head(entity_id_key)
				if err != OK:
					everything_fitted = false
					break

		if everything_fitted:
			synced_last_time.clear()

			# give it a second pass

			for entity_id_key in ctx.co_throttling.clients_sees_entities[client_id].keys():
				if not entity_queue.has_item(entity_id_key):
					if entity_queue.push_head(entity_id_key) != OK:
						break

		#Log.outc(ctx, "deb5 queue size(%s) tail(%s) head(%s) is %s synced_last_time is %s" % [entity_queue.size, entity_queue.tail, entity_queue.head, entity_queue.ring, synced_last_time.keys()], Log.TAG_SYNC_QUEUE)

# queues pairs of client and entity to sync

static func wync_compute_entity_sync_order(ctx: WyncCtx):

	# clear 
	ctx.co_throttling.queue_entity_pairs_to_sync.clear()

	# populate / compute
	
	var entity_index = 0
	var ran_out_of_entities = false

	while (not ran_out_of_entities):
		ran_out_of_entities = true

		# from each client we get the Nth item in queue (entity_index'th)

		for client_id: int in range(1, ctx.common.peers.size()):
			
			var entity_queue := ctx.co_throttling.queue_clients_entities_to_sync[client_id] as FIFORing
			
			# has it?
			if entity_index >= entity_queue.size:
				continue

			var entity_id_key = entity_queue.get_relative_to_tail(entity_index)
			if entity_id_key == -1:
				continue
			var pair = WyncCtx.PeerEntityPair.new()
			pair.peer_id = client_id
			pair.entity_id = entity_id_key
			ctx.co_throttling.queue_entity_pairs_to_sync.append(pair)

			# enough to continue
			ran_out_of_entities = false

		entity_index += 1


# Public
# ----------------------------------------------------------------------


static func wync_everyone_now_can_see_entity(ctx: WyncCtx, entity_id: int) -> void:
	for peer_id in range(1, ctx.common.peers.size()):
		wync_client_now_can_see_entity(ctx, peer_id, entity_id)


static func wync_entity_set_spawn_data(ctx: WyncCtx, entity_id: int, data: Variant, _data_size: int):
	assert(not ctx.co_spawn.entity_spawn_data.has(entity_id))
	ctx.co_spawn.entity_spawn_data[entity_id] = data


static func wync_client_now_can_see_entity(ctx: WyncCtx, client_id: int, entity_id: int) -> int:
	# entity exists
	if not WyncTrack.is_entity_tracked(ctx, entity_id):
		Log.errc(ctx, "entity (%s) isn't tracked")
		return 1

	# already viewed
	if ctx.co_throttling.clients_sees_entities[client_id].has(entity_id):
		return OK

	# add
	var entity_set = ctx.co_throttling.clients_sees_new_entities[client_id] as Dictionary
	entity_set[entity_id] = true

	return OK


static func wync_client_no_longer_sees_entity(ctx: WyncCtx, client_id: int, entity_id: int) -> int:
	# entity exists
	if not WyncTrack.is_entity_tracked(ctx, entity_id):
		Log.errc(ctx, "entity (%s) isn't tracked")
		return 1

	# add
	var entity_set = ctx.co_throttling.clients_no_longer_sees_entities[client_id] as Dictionary
	entity_set[entity_id] = true

	return OK


