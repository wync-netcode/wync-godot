class_name WyncUtils


# Entity / Property functions
# ================================================================


static func track_entity(ctx: WyncCtx, entity_id: int, entity_type_id: int) -> int:
	if ctx.tracked_entities.has(entity_id):
		Log.errc(ctx, "entity (id %s, entity_type_id %s) already tracked" % [entity_id, entity_type_id])
		return 1
	ctx.tracked_entities[entity_id] = true
	ctx.entity_has_props[entity_id] = []
	ctx.entity_is_of_type[entity_id] = entity_type_id
	ctx.entity_last_predicted_tick[entity_id] = -1
	ctx.entity_last_received_tick[entity_id] = -1
	return OK


static func untrack_entity(ctx: WyncCtx, entity_id: int):
	if not WyncUtils.is_entity_tracked(ctx, entity_id):
		return

	Log.outc(ctx, "removing entity (%s)" % [entity_id])
		
	for prop_id: int in ctx.entity_has_props[entity_id]:
		delete_prop(ctx, prop_id)

	ctx.tracked_entities.erase(entity_id)
	ctx.entity_has_props.erase(entity_id)
	ctx.entity_is_of_type.erase(entity_id)
	ctx.entity_has_integrate_fun.erase(entity_id)
	ctx.entity_has_simulation_fun.erase(entity_id)
	ctx.entity_spawn_data.erase(entity_id)
	ctx.entity_last_predicted_tick.erase(entity_id)
	ctx.entity_last_received_tick.erase(entity_id)

	# remove from queues

	for client_id: int in range(1, ctx.peers.size()):
		var entity_queue := ctx.queue_clients_entities_to_sync[client_id] as FIFORing
		entity_queue.remove_item(entity_id)

		var new_seen_entities := ctx.clients_sees_new_entities[client_id] as Dictionary
		new_seen_entities.erase(entity_id)

		# Note: don't remove from 'ctx.client_sees_entities' so that we can know
		# who to send the despawn packet

	ctx.despawned_entity_ids.append(entity_id)


static func delete_prop(ctx: WyncCtx, prop_id: int):
	ctx.active_prop_ids.erase(prop_id)

	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return

	# delete all references to it

	ctx.props[prop_id] = null

	if prop.relative_syncable:
		delete_prop(ctx, prop.auxiliar_delta_events_prop_id)

	ctx.was_any_prop_added_deleted = true
	# free actual prop
	# prop.free()


static func prop_register_minimal(
	ctx: WyncCtx, 
	entity_id: int,
	name_id: String,
	data_type: WyncEntityProp.PROP_TYPE,
	) -> int:
	
	if not is_entity_tracked(ctx, entity_id):
		return -1

	var prop_id = -1

	# if it's pending to spawn then extract the prop_id
	var entity_pending_to_spawn = false

	if WyncUtils.is_client(ctx):
		entity_pending_to_spawn = ctx.pending_entity_to_spawn_props.has(entity_id)
		if entity_pending_to_spawn:
			var entity_auth_props: Array[int] = ctx.pending_entity_to_spawn_props[entity_id]
			prop_id = entity_auth_props[0] + entity_auth_props[2]
			entity_auth_props[2] += 1

	if not entity_pending_to_spawn:
		prop_id = WyncUtils.get_new_prop_id(ctx)

	if prop_id == -1:
		return -1
		
	var prop = WyncEntityProp.new()
	prop.name_id = name_id
	prop.prop_type = data_type

	# instantiate structs
	# todo: some might not be necessary for all
	prop.last_ticks_received = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
	prop.pred_curr = NetTickData.new()
	prop.pred_prev = NetTickData.new()

	# TODO: Dynamic sized buffer for all owned predicted props?
	# TODO: Only do this if this prop is predicted, move to prop_set_predict ?
	if (data_type == WyncEntityProp.PROP_TYPE.INPUT ||
		data_type == WyncEntityProp.PROP_TYPE.EVENT):
		prop.saved_states = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, null)
		prop.state_id_to_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
		prop.tick_to_state_id = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
		prop.state_id_to_local_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1) # only for lerp
	else:
		prop.saved_states = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, null)
		prop.state_id_to_tick = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
		prop.tick_to_state_id = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
		prop.state_id_to_local_tick = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1) # only for lerp
	
	ctx.props[prop_id] = prop
	ctx.active_prop_ids.push_back(prop_id)

	var entity_props = ctx.entity_has_props[entity_id] as Array
	entity_props.append(prop_id)
	
	ctx.was_any_prop_added_deleted = true

	return prop_id


static func prop_register(
	ctx: WyncCtx, 
	entity_id: int,
	name_id: String,
	data_type: WyncEntityProp.PROP_TYPE,
	user_ctx_pointer: Variant, # pointer
	getter: Callable,
	setter: Callable
	) -> int:

	# DEPRECATED

	return -1
	
	"""
	if not is_entity_tracked(ctx, entity_id):
		return -1

	var prop_id = -1

	# if it's pending to spawn then extract the prop_id
	var entity_pending_to_spawn = false

	if WyncUtils.is_client(ctx):
		entity_pending_to_spawn = ctx.pending_entity_to_spawn_props.has(entity_id)
		if entity_pending_to_spawn:
			var entity_auth_props: Array[int] = ctx.pending_entity_to_spawn_props[entity_id]
			prop_id = entity_auth_props[0] + entity_auth_props[2]
			entity_auth_props[2] += 1

	if not entity_pending_to_spawn:
		prop_id = WyncUtils.get_new_prop_id(ctx)

	if prop_id == -1:
		return -1
		
	var prop = WyncEntityProp.new()
	prop.name_id = name_id
	prop.prop_type = data_type
	prop.user_ctx_pointer = user_ctx_pointer
	prop.getter = getter
	prop.setter = setter

	# instantiate structs
	# todo: some might not be necessary for all
	prop.last_ticks_received = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
	prop.arrived_at_tick = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
	prop.pred_curr = NetTickData.new()
	prop.pred_prev = NetTickData.new()

	# TODO: Dynamic sized buffer for all owned predicted props?
	# TODO: Only do this if this prop is predicted, move to prop_set_predict ?
	if (data_type == WyncEntityProp.PROP_TYPE.INPUT ||
		data_type == WyncEntityProp.PROP_TYPE.EVENT):
		prop.confirmed_states = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, null)
		prop.confirmed_states_tick = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE, -1)
	else:
		prop.confirmed_states = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, null)
		prop.confirmed_states_tick = RingBuffer.new(ctx.REGULAR_PROP_CACHED_STATE_AMOUNT, -1)
	
	ctx.props[prop_id] = prop
	ctx.active_prop_ids.push_back(prop_id)

	var entity_props = ctx.entity_has_props[entity_id] as Array
	entity_props.append(prop_id)

	ctx.was_any_prop_added_deleted = true
	
	return prop_id
	"""


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
		WyncFlow.prop_save_confirmed_state(ctx, prop_id, dummy_prop.last_tick, dummy_prop.data)

		# clean up

		ctx.dummy_props.erase(prop_id)

	return OK


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

	if ctx.dummy_props.has(prop_id):
		dummy = ctx.dummy_props[prop_id]
		# free old data
	
	else:
		dummy = WyncCtx.DummyProp.new()
		ctx.dummy_props[prop_id] = dummy

	dummy.last_tick = last_tick
	dummy.data_size = data_size
	dummy.data = data

	return OK


static func get_new_prop_id(ctx) -> int:
	for i in range(ctx.MAX_PROPS):
		
		ctx.prop_id_cursor += 1
		if ctx.prop_id_cursor >= ctx.MAX_PROPS:
			ctx.prop_id_cursor = 0

		if ctx.props[ctx.prop_id_cursor] == null:
			return ctx.prop_id_cursor
	
	return -1


# NOTE: rename to prop_enable_prediction
static func prop_set_predict(ctx: WyncCtx, prop_id: int) -> int:
	var prop := get_prop(ctx, prop_id)
	if prop == null:
		return 1
	ctx.props_to_predict.append(prop_id)

	# TODO: set only if it isn't _delta prop_
	#prop.pred_curr = NetTickData.new()
	#prop.pred_prev = NetTickData.new()
	return OK


# TODO: this is not very well optimized
static func prop_is_predicted(ctx: WyncCtx, prop_id: int) -> bool:
	return ctx.props_to_predict.has(prop_id)
	
static func entity_is_predicted(ctx: WyncCtx, entity_id: int) -> bool:
	if not ctx.entity_has_props.has(entity_id):
		return false
	for prop_id in ctx.entity_has_props[entity_id]:
		if prop_is_predicted(ctx, prop_id):
			return true
	return false

static func entity_has_delta_prop(ctx: WyncCtx, entity_id: int) -> bool:
	if not ctx.entity_has_props.has(entity_id):
		return false
	for prop_id in ctx.entity_has_props[entity_id]:
		var prop := get_prop(ctx, prop_id)
		if prop == null:
			continue
		if prop.relative_syncable:
			return true
	return false

static func prop_set_interpolate(ctx: WyncCtx, prop_id: int, user_data_type: int) -> int:
	if not ctx.is_client:
		return OK
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.user_data_type = user_data_type
	prop.interpolated = true
	return OK
	
static func prop_is_interpolated(ctx: WyncCtx, prop_id: int) -> bool:
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return false
	return prop.interpolated

# server only
static func prop_set_timewarpable(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.timewarpable = true
	prop.saved_states = RingBuffer.new(ctx.max_tick_history_timewarp, null)
	prop.state_id_to_tick = RingBuffer.new(ctx.max_tick_history_timewarp, -1)
	prop.tick_to_state_id = RingBuffer.new(ctx.max_tick_history_timewarp, -1)
	prop.state_id_to_local_tick = RingBuffer.new(ctx.max_tick_history_timewarp, -1) # TODO: this is only for lerp
	
	return OK

# server only
static func prop_is_timewarpable(ctx: WyncCtx, prop_id: int) -> bool:
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return false
	return prop.timewarpable

# server only
static func prop_set_reliability(ctx: WyncCtx, prop_id: int, reliable: bool) -> int:
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.reliable = reliable
	return OK

# server only?
static func prop_set_module_events_consumed(ctx: WyncCtx, prop_id: int) -> int:
	var prop := WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return 1
	prop.module_events_consumed = true
	prop.events_consumed_at_tick = RingBuffer.new(ctx.max_age_user_events_for_consumption, [] as Array[int])
	prop.events_consumed_at_tick_tick = RingBuffer.new(ctx.max_age_user_events_for_consumption, -1)
	return OK


## Only for INPUT / EVENT props
#static func prop_set_prediction_duplication(ctx: WyncCtx, prop_id: int, duplication: bool) -> bool:
	#var prop := WyncUtils.get_prop(ctx, prop_id)
	#if prop == null:
		#return 1
	#prop.allow_duplication_on_tick_skip = duplication
	#return prop.timewarpable


"""
static func prop_set_push_to_global_event(ctx: WyncCtx, prop_id: int, channel: int) -> int:
	if prop_id > ctx.props.size() -1:
		return 1
	var prop = ctx.props[prop_id] as WyncEntityProp
	prop.push_to_global_event = true
	prop.global_event_channel = channel
	return 0"""

# DUMP: create the new INTERNAL service to push all GLOBAL_EVENTS,
# also, maybe cache them in WyncCtx, push the events.


## @returns Optional<WyncEntityProp>
static func entity_get_prop(ctx: WyncCtx, entity_id: int, prop_name_id: StringName) -> WyncEntityProp:
	
	if not is_entity_tracked(ctx, entity_id):
		return null
	
	var entity_prop_ids = ctx.entity_has_props[entity_id] as Array
	
	for prop_id in entity_prop_ids:
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop.name_id == prop_name_id:
			return prop
	
	return null


## @returns int: prop_id; -1 if not found
static func entity_get_prop_id(ctx: WyncCtx, entity_id: int, prop_name_id: StringName) -> int:
	
	if not is_entity_tracked(ctx, entity_id):
		return -1
	
	var entity_prop_ids = ctx.entity_has_props[entity_id] as Array
	
	for prop_id in entity_prop_ids:
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop.name_id == prop_name_id:
			return prop_id
	
	return -1


## @returns int. entity_id; -1 if not found
static func prop_get_entity(ctx: WyncCtx, prop_id: int) -> int:
	for entity_id: int in ctx.tracked_entities.keys():
		if ctx.entity_has_props[entity_id].has(prop_id):
			return entity_id
	return -1


static func is_entity_tracked(ctx: WyncCtx, entity_id: int) -> bool:
	return ctx.tracked_entities.has(entity_id)


# Interpolation / Extrapolation / Prediction functions
# ================================================================


## @returns tuple[int, int]. tick left, tick right
static func prop_find_closest_two_snapshots_from_tick(target_tick: int, prop: WyncEntityProp) -> Array:
	
	var snap_left = -1
	var snap_right = -1
	
	for i in range(prop.last_ticks_received.size):
		var server_tick = prop.last_ticks_received.get_relative(-i)
		if server_tick == -1:
			continue

		# get snapshot from received ticks
		# NOTE: This block shouldn't necessary
		# TODO: before storing check the data is healthy
		#var data = prop.confirmed_states.get_at(server_tick)
		#if data == null:
			#continue

		# get local tick
		var arrived_at_tick = WyncEntityProp.server_tick_arrived_at_local_tick(prop, server_tick)
		if arrived_at_tick == -1:
			continue

		if arrived_at_tick > target_tick:
			snap_right = server_tick
		elif snap_right != -1 && arrived_at_tick <= target_tick:
			snap_left = server_tick
			break
	
	if snap_left == -1:
		return []
	
	return [snap_left, snap_right]


## NOTE: Here we asume `prop.last_ticks_received` is sorted
## @returns tuple[int, int, int, int]. server tick left, server tick right, local tick left, local tick right
static func find_closest_two_snapshots_from_prop(ctx: WyncCtx, target_time_ms: int, prop: WyncEntityProp) -> Array:
	
	## Note: Maybe we don't need local ticks here
	var done_selecting_right = false
	var rhs_tick_server = -1
	var rhs_tick_server_prev = -1
	var rhs_tick_local = -1
	var rhs_tick_local_prev = -1
	var lhs_tick_server = -1
	var lhs_tick_local = -1
	var lhs_timestamp = 0
	var size = prop.last_ticks_received.size

	var server_tick = 0
	var server_tick_prev = 0

	for i in range(size):
		server_tick_prev = server_tick
		server_tick = prop.last_ticks_received.get_absolute(size -1 -i)

		if server_tick == -1:
			if (lhs_tick_server == -1 or
	   			lhs_tick_server >= rhs_tick_server) and rhs_tick_server_prev != -1:

				lhs_tick_server = rhs_tick_server
				lhs_tick_local = rhs_tick_local
				rhs_tick_server = rhs_tick_server_prev
				rhs_tick_local = rhs_tick_local_prev
			else:
				continue
		elif server_tick == server_tick_prev:
			continue


		# This check is necessary because of the current strategy
		# where we sort last_ticks_received causing newer received ticks (albeit older
		# numerically) to overlive older received ticks with higher number
		var data = WyncEntityProp.saved_state_get_throughout(prop, server_tick)
		if data == null:
			continue

		# calculate local tick from server tick
		var local_tick = server_tick - ctx.co_ticks.server_tick_offset
		var snapshot_timestamp = WyncUtils.clock_get_tick_timestamp_ms(ctx, local_tick)

		if not done_selecting_right:

			if snapshot_timestamp > target_time_ms:

				rhs_tick_server_prev = rhs_tick_server
				rhs_tick_local_prev = rhs_tick_local
				rhs_tick_server = server_tick
				rhs_tick_local = local_tick

			else:
				done_selecting_right = true
				if rhs_tick_server == -1:
					rhs_tick_server = server_tick

		if (snapshot_timestamp > lhs_timestamp or
			lhs_tick_server == -1 or
	  		lhs_tick_server >= rhs_tick_server
		):
			lhs_tick_server = server_tick
			lhs_tick_local = local_tick
			lhs_timestamp = snapshot_timestamp
			# TODO: End prematurely when both sides are found

	if (lhs_tick_server == -1 or
		lhs_tick_server >= rhs_tick_server) and rhs_tick_server_prev != -1:

		lhs_tick_server = rhs_tick_server
		lhs_tick_local = rhs_tick_local
		rhs_tick_server = rhs_tick_server_prev
		rhs_tick_local = rhs_tick_local_prev
	
	if lhs_tick_server == -1 || rhs_tick_server == -1:
		return [-1, 0, 0, 0]
	
	return [lhs_tick_server, rhs_tick_server, lhs_tick_local, rhs_tick_local]


## @returns int sim_fun_id
static func register_function(ctx: WyncCtx, sim_fun: Callable) -> int:
	if not sim_fun:
		return -1
	ctx.simulation_functions.append(sim_fun)
	return ctx.simulation_functions.size() -1


static func entity_set_sim_fun(ctx: WyncCtx, entity_id: int, sim_fun_id: int) -> bool:
	ctx.entity_has_simulation_fun[entity_id] = sim_fun_id
	return true


static func entity_set_integration_fun(ctx: WyncCtx, entity_id: int, sim_fun_id: int) -> bool:
	ctx.entity_has_integrate_fun[entity_id] = sim_fun_id
	return true


## @returns optional<Callable>
#static func entity_get_sim_fun(ctx: WyncCtx, entity_id: int):# -> optional<Callable>
	#if not ctx.entity_has_simulation_fun.has(entity_id):
		#return null
	#var sim_fun_id = ctx.entity_has_simulation_fun[entity_id]
	#var sim_fun = ctx.simulation_functions[sim_fun_id]
	#if sim_fun is not Callable:
		#return null
	#return sim_fun


## @returns optional<Callable>
static func entity_get_integrate_fun(ctx: WyncCtx, entity_id: int):# -> optional<Callable>
	if not ctx.entity_has_integrate_fun.has(entity_id):
		return null
	var sim_fun_id = ctx.entity_has_integrate_fun[entity_id]
	var sim_fun = ctx.simulation_functions[sim_fun_id]
	return sim_fun


static func prop_exists(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id < 0 || prop_id >= ctx.MAX_PROPS:
		return false
	var prop = ctx.props[prop_id]
	return prop is WyncEntityProp


## @returns Optional<WyncEntityProp>
static func get_prop(ctx: WyncCtx, prop_id: int) -> WyncEntityProp:
	if prop_id < 0 || prop_id >= ctx.MAX_PROPS:
		return null
	return ctx.props[prop_id]


static func get_prop_unsafe(ctx: WyncCtx, prop_id: int) -> WyncEntityProp:
	return ctx.props[prop_id]


## @returns int:
## * -1 if it belongs to noone (defaults to server)
## * can't return 0
## * returns > 0 (peer_id) if it belongs to a client
static func prop_get_peer_owner(ctx: WyncCtx, prop_id: int) -> int:
	for peer_id in range(1, ctx.max_peers):
		if not ctx.client_owns_prop.has(peer_id):
			continue
		if (ctx.client_owns_prop[peer_id] as Array).has(prop_id):
			return peer_id
	return -1


static func prop_set_client_owner(ctx: WyncCtx, prop_id: int, client_id: int) -> bool:
	# NOTE: maybe don't check because this prop could be synced later
	#if not prop_exists(ctx, prop_id):
		#return false
	if not ctx.client_owns_prop.has(client_id):
		ctx.client_owns_prop[client_id] = []
	ctx.client_owns_prop[client_id].append(prop_id)

	ctx.client_ownership_updated = true
	return true


# Setup functions
# ================================================================


## Server side function
## @argument peer_data (optional): store a custom int if needed. Use it to save an external identifier. This is usually the transport's peer_id
 
static func peer_register(ctx: WyncCtx, peer_data: int = -1) -> int:
	var peer_id = ctx.peers.size()
	ctx.peers.append(peer_data)
	ctx.client_owns_prop[peer_id] = []
	ctx.client_has_relative_prop_has_last_tick[peer_id] = {}
	
	ctx.client_has_info[peer_id] = WyncClientInfo.new()

	return peer_id


static func server_setup(ctx: WyncCtx) -> int:
	# peer id 0 reserved for server
	ctx.is_client = false
	ctx.my_peer_id = 0
	ctx.peers.resize(1)
	ctx.peers[ctx.my_peer_id] = -1
	ctx.connected = true

	# setup event caching
	ctx.events_hash_to_id.init(ctx.max_amount_cache_events)
	ctx.to_peers_i_sent_events = []
	ctx.to_peers_i_sent_events.resize(ctx.max_peers)
	for i in range(ctx.max_peers):
		ctx.to_peers_i_sent_events[i] = FIFOMap.new()
		ctx.to_peers_i_sent_events[i].init(ctx.max_amount_cache_events)

	# setup relative synchronization
	ctx.peers_events_to_sync = []
	ctx.peers_events_to_sync.resize(ctx.max_peers)
	for i in range(ctx.max_peers):
		ctx.peers_events_to_sync[i] = {} as Dictionary

	# setup peer channels
	WyncUtils.setup_peer_global_events(ctx, WyncCtx.SERVER_PEER_ID)
	for i in range(1, ctx.max_peers):
		WyncUtils.setup_peer_global_events(ctx, i)

	WyncUtils.setup_entity_prob_for_entity_update_delay_ticks(ctx, WyncCtx.SERVER_PEER_ID)

	# setup prob prop
	return 0


static func client_init(ctx: WyncCtx) -> int:
	ctx.is_client = true
	return OK
	

## Client side function

static func client_setup_my_client(ctx: WyncCtx, peer_id: int) -> bool:
	ctx.my_peer_id = peer_id

	# we might have received WYNC_PKT_RES_CLIENT_INFO before
	if not ctx.client_owns_prop.has(peer_id):
		ctx.client_owns_prop[peer_id] = []

	# setup event caching
	ctx.events_hash_to_id.init(ctx.max_amount_cache_events)
	ctx.to_peers_i_sent_events = []
	ctx.to_peers_i_sent_events.resize(1)
	ctx.to_peers_i_sent_events[ctx.SERVER_PEER_ID] = FIFOMap.new()
	ctx.to_peers_i_sent_events[ctx.SERVER_PEER_ID].init(ctx.max_amount_cache_events)

	# setup relative synchronization
	ctx.peers_events_to_sync = []
	ctx.peers_events_to_sync.resize(1)
	ctx.peers_events_to_sync[ctx.SERVER_PEER_ID] = {} as Dictionary

	# setup peer channels
	WyncUtils.setup_peer_global_events(ctx, WyncCtx.SERVER_PEER_ID)
	for i in range(1, ctx.max_peers):
		WyncUtils.setup_peer_global_events(ctx, i)
	
	# setup server global events
	#WyncUtils.setup_peer_global_events(ctx, ctx.SERVER_PEER_ID)
	# setup own global events
	#WyncUtils.setup_peer_global_events(ctx, ctx.my_peer_id)
	# setup prob prop
	WyncUtils.setup_entity_prob_for_entity_update_delay_ticks(ctx, ctx.my_peer_id)

	return true


## @returns int: peer_id if found; -1 if not found
static func is_peer_registered(ctx: WyncCtx, peer_data: int) -> int:
	for peer_id: int in range(ctx.peers.size()):
		var i_peer_data = ctx.peers[peer_id]
		if i_peer_data == peer_data:
			return peer_id
	return -1


static func wync_set_my_nete_peer_id (ctx: WyncCtx, nete_peer_id: int) -> int:
	ctx.my_nete_peer_id = nete_peer_id
	return OK


## Client only
static func wync_set_server_nete_peer_id (ctx: WyncCtx, nete_peer_id: int) -> int:
	if ctx.peers.size() == 0:
		ctx.peers.resize(1)
	ctx.peers[0] = nete_peer_id
	ctx.my_nete_peer_id = nete_peer_id
	return OK


## Gets nete_peer_id from a given wync_peer_id
## Used to know to whom to send packets
## @returns int: nete_peer_id if found; -1 if not found
static func get_nete_peer_id_from_wync_peer_id (ctx: WyncCtx, wync_peer_id: int) -> int:
	if wync_peer_id >= 0 && wync_peer_id < ctx.peers.size():
		return ctx.peers[wync_peer_id]
	return -1


## TODO: maybe we could compute this every time we get an update?
## Only predicted props
## Exclude props I own (Or just exclude TYPE_INPUT?) What about events or delta props?
static func entity_get_last_received_tick_from_pred_props (ctx: WyncCtx, entity_id: int) -> int:
	if not is_entity_tracked(ctx, entity_id):
		return -1

	var last_tick = -1 
	for prop_id: int in ctx.entity_has_props[entity_id]:

		var prop := get_prop(ctx, prop_id)
		if prop == null:
			continue

		var prop_last_tick = prop.last_ticks_received.get_relative(0)
		if prop_last_tick == -1:
			continue

		if ctx.client_owns_prop[ctx.my_peer_id].has(prop_id):
			continue

		if last_tick == -1:
			last_tick = prop_last_tick
		else:
			last_tick = min(last_tick, prop_last_tick)

	#Log.outc(ctx, "entity_id %s last_tick %s" % [entity_id, last_tick])
	return last_tick


"""
static func setup_general_global_events(ctx: WyncCtx) -> int:
	ctx.global_events_channel.resize(WyncCtx.MAX_GLOBAL_EVENT_CHANNELS)
	print("GlobalEvent | %s" % [ctx.global_events_channel])

	var entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS
	WyncUtils.track_entity(ctx, entity_id)
	var prop_channel_0 = WyncUtils.prop_register(
		ctx,
		entity_id,
		"channel_0",
		WyncEntityProp.DATA_TYPE.EVENT,
		func(): return [], # getter
		func(input: Array): # setter
			ctx.global_events_channel[0].clear()
			ctx.global_events_channel[0].append_array(input),
	)
	if (WyncUtils.is_client(ctx)):
		WyncUtils.prop_set_predict(ctx, prop_channel_0)

	return 0"""


# run on both server & client to set up peer channel
# NOTE: Maybe it's better to initialize all client channels from the start
static func setup_peer_global_events(ctx: WyncCtx, peer_id: int) -> int:
	assert(ctx.connected)
	
	var entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + peer_id
	WyncUtils.track_entity(ctx, entity_id, -1)
	var channel_id = 0
	var channel_prop_id = WyncUtils.prop_register_minimal(
		ctx,
		entity_id,
		"channel_%d" % [channel_id],
		WyncEntityProp.PROP_TYPE.EVENT
	)
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		channel_prop_id,
		ctx,
		func(wync_ctx: Variant) -> Array: # getter
			return (wync_ctx as WyncCtx).peer_has_channel_has_events[peer_id][channel_id].duplicate(true),
		func(wync_ctx: Variant, input: Array): # setter
			var event_array = (wync_ctx as WyncCtx).peer_has_channel_has_events[peer_id][channel_id] as Array
			event_array.clear()
			event_array.append_array(input),
	)

	# TODO: add as VIP prop

	# predict my own global channel
	if (ctx.is_client && peer_id == ctx.my_peer_id):
		WyncUtils.prop_set_predict(ctx, channel_prop_id)

	# TODO: why only run on server? Q: ...
	#if not ctx.is_client:
	if true:
		# add as local existing prop
		WyncThrottle.wync_add_local_existing_entity(ctx, peer_id, entity_id)
		# server module for consuming user events
		prop_set_module_events_consumed(ctx, channel_prop_id)
		# populate ctx var
		ctx.prop_id_by_peer_by_channel[peer_id][channel_id] = channel_prop_id

	return 0


static func setup_entity_prob_for_entity_update_delay_ticks(ctx: WyncCtx, peer_id: int) -> int:

	# The prob prop acts is a low priority entity to sync, it's purpose it's to
	# allow us to measure how much ticks of delay there are between updates for
	# a especific single prop, based on that we can get a better stimate for
	# _prediction threeshold_
	
	var entity_id = WyncCtx.ENTITY_ID_PROB_FOR_ENTITY_UPDATE_DELAY_TICKS
	WyncUtils.track_entity(ctx, entity_id, -1)
	var prop_prob = WyncUtils.prop_register_minimal(
		ctx,
		entity_id,
		"entity_prob",
		WyncEntityProp.PROP_TYPE.STATE
	)
	# TODO: internal functions shouldn't be using wrapper functions...
	# Maybe we can treat these differently? These are all internal, so it
	# doesn't make sense to require external functions like the wrapper's
	WyncWrapper.wync_set_prop_callbacks(
		ctx,
		prop_prob,
		ctx,
		func(p_ctx: Variant) -> int: # getter
			# use any value that constantly changes, don't really need to read it
			return (p_ctx as WyncCtx).co_ticks.ticks, 
		func(_prob_ctx: Variant, _value: Variant): # setter
			pass,
	)
	if prop_prob != -1:
		ctx.PROP_ID_PROB = prop_prob

	# add as local existing prop
	if not WyncUtils.is_client(ctx):
		WyncThrottle.wync_add_local_existing_entity(ctx, peer_id, entity_id)

	return 0


# Loop functions: Functions or 'systems' that are intented to run on the game loops
# ================================================================

## extract events from props DATA_TYPE.EVENT global
## and inserts/duplicates them into the ctx.global_events_channel

"""
static func system_publish_global_events(ctx: WyncCtx, tick: int) -> void:
	return
	# TODO: optimize with caching maybe
	for prop: WyncEntityProp in ctx.props:
		if not prop:
			continue
		if (!prop.push_to_global_event):
			continue
		if (prop.global_event_channel < 0):
			continue
		if (prop.data_type != WyncEntityProp.DATA_TYPE.EVENT):
			continue

		var input = prop.confirmed_states.get_at(tick)
		if input == null:
			continue
		if input is not Array:
			continue
		input = input as Array"""
		
		# FIXME
#ctx.global_events_channel[prop.global_event_channel].append_array(input)


# Miscellanious
# ================================================================

# TODO: being able to determine wether we're a client or not even before connecting
static func is_client(ctx: WyncCtx, peer_id: int = -1) -> bool:
	if peer_id >= 0:
		return peer_id > 0
	return ctx.my_peer_id > 0


static func duplicate_any(any): #-> Optional<any>
	if any is Object:
		if any.has_method("duplicate") && any is not Node:
			return any.duplicate()
		elif any.has_method("copy"):
			return any.copy()
		elif any.has_method("make_duplicate"):
			return any.make_duplicate()
	elif typeof(any) in [
		TYPE_ARRAY,
		TYPE_DICTIONARY
	]:
		return any.duplicate(true)
	elif typeof(any) in [
		TYPE_BOOL,
		TYPE_INT,
		TYPE_FLOAT,
		TYPE_STRING,
		TYPE_VECTOR2,
		TYPE_VECTOR2I,
		TYPE_RECT2,
		TYPE_RECT2I,
		TYPE_VECTOR3,
		TYPE_VECTOR3I,
		TYPE_TRANSFORM2D,
		TYPE_VECTOR4,
		TYPE_VECTOR4I,
		TYPE_PLANE,
		TYPE_QUATERNION,
		TYPE_AABB,
		TYPE_BASIS,
		TYPE_TRANSFORM3D,
		TYPE_PROJECTION,
		TYPE_COLOR,
		TYPE_STRING_NAME
	]:
		return any
	return null


static func lerp_any(left: Variant, right: Variant, weight: float):
	return lerp(left, right, weight)


## denominator must be a power of 2
static func fast_modulus(numerator: int, denominator: int) -> int:
	## NOTE: DEBUG flag only: assert(denominator is power of 2)
	return numerator & (denominator - 1)


# Note: Set physics ticks is in WyncFlow


static func clock_set_debug_time_offset(ctx: WyncCtx, time_offset_ms: int):
	ctx.co_ticks.debug_time_offset_ms = time_offset_ms


static func clock_get_ms(ctx: WyncCtx) -> float:
	return float(Time.get_ticks_usec()) / 1000 + ctx.co_ticks.debug_time_offset_ms


static func clock_get_tick_timestamp_ms(ctx: WyncCtx, ticks: int) -> float:
	var frame = 1000.0 / Engine.physics_ticks_per_second
	return ctx.co_predict_data.current_tick_timestamp + (ticks - ctx.co_ticks.ticks) * frame


static func clear_peers_pending_to_setup(ctx: WyncCtx):
	ctx.out_peer_pending_to_setup.clear()


## Server only
## Sends data
static func wync_system_sync_client_ownership(ctx: WyncCtx):
	if not ctx.client_ownership_updated:
		return
	ctx.client_ownership_updated = false

	# update all clients about their prop ownership

	for wync_client_id in range(1, ctx.peers.size()):
		# TODO: Check peer health / is connected
		for prop_id: int in ctx.client_owns_prop[wync_client_id] as Array[int]:

			var packet = WyncPktResClientInfo.new()
			packet.prop_id = prop_id
			packet.peer_id = wync_client_id

			var result = WyncFlow.wync_wrap_packet_out(ctx, wync_client_id, WyncPacket.WYNC_PKT_RES_CLIENT_INFO, packet)
			if result[0] == OK:
				var packet_out = result[1] as WyncPacketOut
				WyncThrottle.wync_try_to_queue_out_packet(ctx, packet_out, WyncCtx.RELIABLE, true)


static func out_client_just_connected_to_server(ctx: WyncCtx) -> bool:
	var just_connected: bool = ctx.connected && not ctx._prev_connected
	ctx._prev_connected = ctx.connected
	return just_connected
