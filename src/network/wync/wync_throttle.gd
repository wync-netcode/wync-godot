class_name WyncThrottle

# Systems
# ----------------------------------------------------------------------


## TODO: fix all these comments
## @argument commit: bool. Pass True if you're gonna send this message through the network,
## so that Wync can assume it will arrive
## This system is network throttled
## Note: as it is the first clients have priority until the out buffer fills
static func wync_system_send_entities_to_spawn(ctx: WyncCtx, _commit: bool = true) -> int:
	var data_used = 0
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
			packet.entity_type_ids[i] = ctx.entity_is_of_type[entity_id]
			var entity_prop_ids = ctx.entity_has_props[entity_id]
			assert(entity_prop_ids.size() > 0)
			packet.entity_prop_id_start[i] = entity_prop_ids[0]
			packet.entity_prop_id_end[i] = entity_prop_ids[entity_prop_ids.size() -1]

			if ctx.entity_spawn_data.has(entity_id):
				packet.entity_spawn_data[i] = WyncUtils.duplicate_any(ctx.entity_spawn_data[entity_id])

			# commit / confirm as _client can see it_

			_wync_confirm_client_can_see_entity(ctx, client_id, entity_id)

			data_used += HashUtils.calculate_wync_packet_data_size(WyncPacket.WYNC_PKT_SPAWN)
			if (data_used >= ctx.out_packets_size_remaining_chars):
				break

		if ((i + 1) != entity_amount):
			packet.resize(i + 1)

		# queue 
		var res = WyncFlow.wync_wrap_packet_out(ctx, client_id, WyncPacket.WYNC_PKT_SPAWN, packet)
		if res[0] == OK:
			var pkt_out = res[1] as WyncPacketOut
			WyncThrottle.wync_try_to_queue_out_packet(ctx, pkt_out, WyncCtx.RELIABLE, true)

		if (data_used >= ctx.out_packets_size_remaining_chars):
			break
		
	return OK


# This system is not throttled
static func wync_system_send_entities_to_despawn(ctx: WyncCtx, _commit: bool = true) -> int:

	for client_id in range(1, ctx.peers.size()):

		var current_entities_set = ctx.clients_sees_entities[client_id] as Dictionary
		var entity_id_list: Array[int] = []
		var entity_amount = 0

		for entity_id: int in ctx.despawned_entity_ids:
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
		var res = WyncFlow.wync_wrap_packet_out(ctx, client_id, WyncPacket.WYNC_PKT_DESPAWN, packet)
		assert(res[0] == OK)
		var pkt_out = res[1] as WyncPacketOut
		WyncThrottle.wync_try_to_queue_out_packet(ctx, pkt_out, WyncCtx.RELIABLE, true)

	ctx.despawned_entity_ids.clear()

	return OK


## Calls all the systems that produce packets to send whilst respecting the data limit

static func wync_system_gather_packets(ctx: WyncCtx):

	if ctx.is_client:
		if not ctx.connected:
			WyncFlow.wync_try_to_connect(ctx)                     # reliable, commited
		else:
			SyWyncClockServer.wync_client_ask_for_clock(ctx)      # unreliable
			WyncFlow.wync_system_client_send_delta_prop_acks(ctx) # unreliable
			SyWyncSendInputs.wync_client_send_inputs(ctx)         # unreliable
			SyWyncSendEventData.wync_send_event_data(ctx)         # reliable, commited

	else:
		WyncThrottle.wync_system_send_entities_to_despawn(ctx) # reliable, commited
		WyncThrottle.wync_system_send_entities_to_spawn(ctx)   # reliable, commited
		WyncUtils.wync_system_sync_client_ownership(ctx)       # reliable, commited

		WyncThrottle.wync_system_fill_entity_sync_queue(ctx)
		WyncThrottle.wync_compute_entity_sync_order(ctx)
		SyWyncStateExtractor.wync_send_extracted_data(ctx) # both reliable/unreliable

	WyncThrottle.wync_system_calculate_data_per_tick(ctx)


## calculate statistic data per tick
static func wync_system_calculate_data_per_tick(ctx: WyncCtx):

	var data_sent = ctx.out_packets_size_limit - ctx.out_packets_size_remaining_chars
	ctx.debug_data_per_tick_current = data_sent

	ctx.debug_ticks_sent += 1
	ctx.debug_data_per_tick_total_mean = (ctx.debug_data_per_tick_total_mean * (ctx.debug_ticks_sent -1) + data_sent) / float(ctx.debug_ticks_sent)

	ctx.debug_data_per_tick_sliding_window.push(data_sent)
	var data_sent_acc = 0
	for i in range(ctx.debug_data_per_tick_sliding_window_size):
		var value = ctx.debug_data_per_tick_sliding_window.get_at(i)
		if value is int:
			data_sent_acc += ctx.debug_data_per_tick_sliding_window.get_at(i)
	ctx.debug_data_per_tick_sliding_window_mean = data_sent_acc / ctx.debug_data_per_tick_sliding_window_size


# TODO: rename
static func _wync_remove_entity_from_sync_queue(ctx: WyncCtx, peer_id: int, entity_id: int):
	var synced_last_time = ctx.entities_synced_last_time[peer_id] as Dictionary
	synced_last_time[entity_id] = true

	var entity_queue := ctx.queue_clients_entities_to_sync[peer_id] as FIFORing
	var saved_entity_id = entity_queue.pop_tail()

	#Log.outc(ctx, "deb5 marking entity as already synced %s" % [entity_id], Log.TAG_SYNC_QUEUE)
	#Log.outc(ctx, "deb5 synced_last_time is %s" % [synced_last_time.keys()], Log.TAG_SYNC_QUEUE)

	# FIXME
	assert(saved_entity_id == entity_id)


# Just appends entity_id's into the queue 

static func wync_system_fill_entity_sync_queue(ctx: WyncCtx):

	for client_id: int in range(1, ctx.peers.size()):

		var entity_queue := ctx.queue_clients_entities_to_sync[client_id] as FIFORing
		var synced_last_time := ctx.entities_synced_last_time[client_id] as Dictionary
		var everything_fitted = true

		for entity_id_key in ctx.clients_sees_entities[client_id].keys():

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

			for entity_id_key in ctx.clients_sees_entities[client_id].keys():
				if not entity_queue.has_item(entity_id_key):
					if entity_queue.push_head(entity_id_key) != OK:
						break

		#Log.outc(ctx, "deb5 queue size(%s) tail(%s) head(%s) is %s synced_last_time is %s" % [entity_queue.size, entity_queue.tail, entity_queue.head, entity_queue.ring, synced_last_time.keys()], Log.TAG_SYNC_QUEUE)

# queues pairs of client and entity to sync

static func wync_compute_entity_sync_order(ctx: WyncCtx):

	# clear 
	ctx.queue_entity_pairs_to_sync.clear()

	# populate / compute
	
	var entity_index = 0
	var ran_out_of_entities = false

	while (not ran_out_of_entities):
		ran_out_of_entities = true

		# from each client we get the Nth item in queue (entity_index'th)

		for client_id: int in range(1, ctx.peers.size()):
			
			var entity_queue := ctx.queue_clients_entities_to_sync[client_id] as FIFORing
			
			# has it?
			if entity_index >= entity_queue.size:
				continue

			var entity_id_key = entity_queue.get_relative_to_tail(entity_index)
			if entity_id_key == -1:
				continue
			var pair = WyncCtx.PeerEntityPair.new()
			pair.peer_id = client_id
			pair.entity_id = entity_id_key
			ctx.queue_entity_pairs_to_sync.append(pair)

			# enough to continue
			ran_out_of_entities = false

		entity_index += 1


# Utils
# ----------------------------------------------------------------------


static func wync_everyone_now_can_see_entity(ctx: WyncCtx, entity_id: int) -> void:
	for peer_id in range(1, ctx.peers.size()):
		wync_client_now_can_see_entity(ctx, peer_id, entity_id)


static func wync_entity_set_spawn_data(ctx: WyncCtx, entity_id: int, data: Variant, _data_size: int):
	assert(not ctx.entity_spawn_data.has(entity_id))
	ctx.entity_spawn_data[entity_id] = data


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


#static func _wync_confirm_client_entity_visibility \
		#(ctx: WyncCtx, client_id: int, entity_id: int, visible: bool):
	
	#var entity_set = ctx.clients_no_longer_sees_entities[client_id] as Dictionary

	#if visible:
		#entity_set[entity_id] = true
	#else:
		#entity_set.erase(entity_id)
	
	
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
		(ctx: WyncCtx, wync_client_id: int, entity_id: int) -> int:

	if WyncUtils.is_client(ctx):
		return 1
	if wync_client_id == WyncCtx.SERVER_PEER_ID:
		return 2
	if not WyncUtils.is_entity_tracked(ctx, entity_id): # entity exists
		Log.err("entity (%s) isn't tracked", Log.TAG_THROTTLE)
		return 3

	var entity_set = ctx.clients_sees_entities[wync_client_id]
	entity_set[entity_id] = true

	# remove from new entities

	var new_entity_set = ctx.clients_sees_new_entities[wync_client_id] as Dictionary
	new_entity_set.erase(entity_id)

	return OK


## TODO: this function is too similar to wync_add_local_existing_entity
## Removes an entity from clients_sees_new_entities
static func _wync_confirm_client_can_see_entity(ctx: WyncCtx, client_id: int, entity_id: int):

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

	Log.outc(ctx, "I: spawn, confirmed: client %s can now see entity %s" % [
		client_id, entity_id])


## Call every time before gathering packets
static func wync_set_data_limit_chars_for_out_packets(ctx: WyncCtx, data_limit_chars: int):
	ctx.out_packets_size_limit = data_limit_chars
	ctx.out_packets_size_remaining_chars = data_limit_chars


## In case we can't queue a packet stop generatin' packets
## @argument dont_occuppy: bool. Used for inserting packets which size was already reserved
## @returns int: Error
static func wync_try_to_queue_out_packet (
	ctx: WyncCtx,
	out_packet: WyncPacketOut,
	reliable: bool,
	already_commited: bool,
	dont_ocuppy: bool = false,
	) -> int:

	var packet_size = HashUtils.calculate_wync_packet_data_size(out_packet.data.packet_type_id)
	if packet_size >= ctx.out_packets_size_remaining_chars:
		if already_commited:
			#Log.err("(%s) COMMITED anyways, Packet too big (%s), remaining data (%s), d(%s)" %
			#[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id],
			#packet_size,
			#ctx.out_packets_size_remaining_chars,
			#packet_size-ctx.out_packets_size_remaining_chars])
			pass
		else:
			Log.errc(ctx, "(%s) DROPPED, Packet too big (%s), remaining data (%s), d(%s)" %
			[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id],
			packet_size,
			ctx.out_packets_size_remaining_chars,
			packet_size-ctx.out_packets_size_remaining_chars])
			return 1

	if not dont_ocuppy:
		ctx.out_packets_size_remaining_chars -= packet_size
	
	if reliable:
		ctx.out_reliable_packets.append(out_packet)
	else:
		ctx.out_unreliable_packets.append(out_packet)

	#Log.outc(ctx, "queued packet %s, remaining data (%s)" %
	#[WyncPacket.PKT_NAMES[out_packet.data.packet_type_id], ctx.out_packets_size_remaining_chars])
	return OK


## Just like the function above, except this just "ocuppies" space without queuing anything
## Used for preserving space for queuing event data.
static func wync_ocuppy_space_towards_packets_data_size_limit(ctx: WyncCtx, chars: int):
	ctx.out_packets_size_remaining_chars -= chars
