class_name WyncTrack

## Tracks game data


# Entity / Property functions
# ================================================================


static func track_entity(ctx: WyncCtx, entity_id: int, entity_type_id: int) -> int:
	if ctx.co_track.tracked_entities.has(entity_id):
		Log.errc(ctx, "entity (id %s, entity_type_id %s) already tracked" % [entity_id, entity_type_id])
		return 1
	ctx.co_track.tracked_entities[entity_id] = true
	ctx.co_track.entity_has_props[entity_id] = []
	ctx.co_track.entity_is_of_type[entity_id] = entity_type_id
	ctx.co_pred.entity_last_predicted_tick[entity_id] = -1
	ctx.co_pred.entity_last_received_tick[entity_id] = -1
	return OK


static func untrack_entity(ctx: WyncCtx, entity_id: int):
	if not WyncTrack.is_entity_tracked(ctx, entity_id):
		return

	Log.outc(ctx, "removing entity (%s)" % [entity_id])
		
	for prop_id: int in ctx.co_track.entity_has_props[entity_id]:
		delete_prop(ctx, prop_id)

	ctx.co_track.tracked_entities.erase(entity_id)
	ctx.co_track.entity_has_props.erase(entity_id)
	ctx.co_track.entity_is_of_type.erase(entity_id)
	ctx.co_spawn.entity_spawn_data.erase(entity_id)
	ctx.co_pred.entity_last_predicted_tick.erase(entity_id)
	ctx.co_pred.entity_last_received_tick.erase(entity_id)

	# remove from queues

	for client_id: int in range(1, ctx.common.peers.size()):
		var entity_queue := ctx.co_throttling.queue_clients_entities_to_sync[client_id] as FIFORing
		entity_queue.remove_item(entity_id)

		var new_seen_entities := ctx.co_throttling.clients_sees_new_entities[client_id] as Dictionary
		new_seen_entities.erase(entity_id)

		# Note: don't remove from 'ctx.client_sees_entities' so that we can know
		# who to send the despawn packet

	ctx.co_spawn.despawned_entity_ids.append(entity_id)


static func delete_prop(ctx: WyncCtx, prop_id: int):
	ctx.co_track.active_prop_ids.erase(prop_id)

	var prop = WyncTrack.get_prop(ctx, prop_id)
	if prop == null:
		return

	# delete all references to it

	ctx.co_track.props[prop_id] = null

	if prop.relative_sync_enabled:
		delete_prop(ctx, prop.auxiliar_delta_events_prop_id)

	ctx.common.was_any_prop_added_deleted = true

	# free actual prop
	# prop.free()
	# free modules


static func prop_register_minimal(
	ctx: WyncCtx, 
	entity_id: int,
	name_id: String,
	data_type: WyncCtx.PROP_TYPE,
	) -> int:
	
	if not is_entity_tracked(ctx, entity_id):
		return -1

	var prop_id = -1

	# if pending to spawn then extract the prop_id

	var entity_pending_to_spawn = false

	if ctx.common.is_client:
		entity_pending_to_spawn = ctx.co_spawn.pending_entity_to_spawn_props.has(entity_id)
		if entity_pending_to_spawn:
			var entity_auth_props: Array[int] = ctx.co_spawn.pending_entity_to_spawn_props[entity_id]
			prop_id = entity_auth_props[0] + entity_auth_props[2]
			entity_auth_props[2] += 1

	if not entity_pending_to_spawn:
		prop_id = WyncTrack.get_new_prop_id(ctx)

	if prop_id == -1:
		return -1
		
	var prop = WyncProp.new()
	prop.name_id = name_id
	prop.prop_type = data_type

	prop.statebff = WyncProp.StateBuffer.new()

	# instantiate structs
	# todo: some might not be necessary for all
	prop.statebff.last_ticks_received = RingBuffer.new(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)

	# TODO: Dynamic sized buffer for all owned predicted props?
	# TODO: Only do this if this prop is predicted, move to prop_set_predict ?
	if (data_type == WyncCtx.PROP_TYPE.INPUT ||
		data_type == WyncCtx.PROP_TYPE.EVENT):
		prop.statebff.saved_states = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, null)
		prop.statebff.state_id_to_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
		prop.statebff.tick_to_state_id = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
		prop.statebff.state_id_to_local_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1) # only for lerp
	else:
		prop.statebff.saved_states = RingBuffer.new(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT, null)
		prop.statebff.state_id_to_tick = RingBuffer.new(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
		prop.statebff.tick_to_state_id = RingBuffer.new(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
		prop.statebff.state_id_to_local_tick = RingBuffer.new(ctx.co_track.REGULAR_PROP_CACHED_STATE_AMOUNT, -1) # only for lerp
	
	ctx.co_track.props[prop_id] = prop
	ctx.co_track.active_prop_ids.push_back(prop_id)

	var entity_props = ctx.co_track.entity_has_props[entity_id] as Array
	entity_props.append(prop_id)
	
	ctx.common.was_any_prop_added_deleted = true

	return prop_id


static func get_new_prop_id(ctx) -> int:
	for i in range(ctx.MAX_PROPS):
		
		ctx.co_track.prop_id_cursor += 1
		if ctx.co_track.prop_id_cursor >= ctx.MAX_PROPS:
			ctx.co_track.prop_id_cursor = 0

		if ctx.co_track.props[ctx.co_track.prop_id_cursor] == null:
			return ctx.co_track.prop_id_cursor
	
	return -1


## @returns Optional<WyncProp>
static func entity_get_prop(ctx: WyncCtx, entity_id: int, prop_name_id: StringName) -> WyncProp:
	
	if not is_entity_tracked(ctx, entity_id):
		return null
	
	var entity_prop_ids = ctx.co_track.entity_has_props[entity_id] as Array
	
	for prop_id in entity_prop_ids:
		var prop = get_prop(ctx, prop_id)
		if prop.name_id == prop_name_id:
			return prop
	
	return null


## @returns Array[int]
static func entity_get_prop_id_list(ctx: WyncCtx, entity_id: int) -> Array:
	
	if not is_entity_tracked(ctx, entity_id):
		return []
	
	return ctx.co_track.entity_has_props[entity_id] as Array


## @returns int: prop_id; -1 if not found
static func entity_get_prop_id(ctx: WyncCtx, entity_id: int, prop_name_id: StringName) -> int:
	
	if not is_entity_tracked(ctx, entity_id):
		return -1
	
	var entity_prop_ids = ctx.co_track.entity_has_props[entity_id] as Array
	
	for prop_id in entity_prop_ids:
		var prop = ctx.co_track.props[prop_id] as WyncProp
		if prop.name_id == prop_name_id:
			return prop_id
	
	return -1


## @returns int. entity_id; -1 if not found
## TODO: have a structure for direct access instead of searching
static func prop_get_entity(ctx: WyncCtx, prop_id: int) -> int:
	for entity_id: int in ctx.co_track.tracked_entities.keys():
		if ctx.co_track.entity_has_props[entity_id].has(prop_id):
			return entity_id
	return -1


static func is_entity_tracked(ctx: WyncCtx, entity_id: int) -> bool:
	return ctx.co_track.tracked_entities.has(entity_id)


static func prop_exists(ctx: WyncCtx, prop_id: int) -> bool:
	return get_prop(ctx, prop_id) != null


## @returns Optional<WyncProp>
static func get_prop(ctx: WyncCtx, prop_id: int) -> WyncProp:
	if prop_id < 0 || prop_id >= ctx.MAX_PROPS:
		return null
	return ctx.co_track.props[prop_id]


static func get_prop_unsafe(ctx: WyncCtx, prop_id: int) -> WyncProp:
	return ctx.co_track.props[prop_id]


## Use everytime we get state from a prop we don't have
## Dummy props will be naturally deleted over time
static func prop_register_update_dummy(
	ctx: WyncCtx, 
	prop_id: int,
	last_tick: int,
	data_size: int,
	data: Variant,
	) -> int:

	var dummy: WyncCtx.DummyProp = null

	# check if a dummy exists

	if ctx.co_dummy.dummy_props.has(prop_id):
		dummy = ctx.co_dummy.dummy_props[prop_id]
		# free old data
	
	else:
		dummy = WyncCtx.DummyProp.new()
		ctx.co_dummy.dummy_props[prop_id] = dummy

	dummy.last_tick = last_tick
	dummy.data_size = data_size
	dummy.data = data

	return OK


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

	if ctx.common.is_client:
		return 1
	if wync_client_id == WyncCtx.SERVER_PEER_ID:
		return 2
	if not WyncTrack.is_entity_tracked(ctx, entity_id): # entity exists
		Log.errc(ctx, "entity (%s) isn't tracked")
		return 3

	var entity_set = ctx.co_throttling.clients_sees_entities[wync_client_id]
	entity_set[entity_id] = true

	# remove from new entities

	var new_entity_set = ctx.co_throttling.clients_sees_new_entities[wync_client_id] as Dictionary
	new_entity_set.erase(entity_id)

	return OK
