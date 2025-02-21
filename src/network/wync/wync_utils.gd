class_name WyncUtils


# Entity / Property functions
# ================================================================


static func track_entity(ctx: WyncCtx, entity_id: int):
	ctx.tracked_entities[entity_id] = true
	ctx.entity_has_props[entity_id] = []


static func prop_register(
	ctx: WyncCtx, 
	entity_id: int,
	name_id: String,
	data_type: WyncEntityProp.DATA_TYPE,
	getter: Callable,
	setter: Callable
	) -> int:
	
	if not is_entity_tracked(ctx, entity_id):
		return -1
		
	var prop = WyncEntityProp.new()
	prop.name_id = name_id
	prop.data_type = data_type
	prop.getter = getter
	prop.setter = setter

	# TODO: Dynamic sized buffer for all owned predicted props?
	# TODO: Only do this if this prop is predicted
	if (data_type == WyncEntityProp.DATA_TYPE.INPUT ||
		data_type == WyncEntityProp.DATA_TYPE.EVENT):
		prop.confirmed_states = RingBuffer.new(WyncCtx.INPUT_BUFFER_SIZE)
	
	var prop_id = ctx.props.size()
	var entity_props = ctx.entity_has_props[entity_id] as Array
	ctx.props.append(prop)
	entity_props.append(prop_id)
	
	return prop_id


# NOTE: rename to prop_enable_prediction
static func prop_set_predict(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	ctx.props_to_predict.append(prop_id)
	return true


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

static func prop_set_interpolate(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id] as WyncEntityProp
	if prop.data_type not in WyncEntityProp.INTERPOLABLE_DATA_TYPES:
		return false
	prop.interpolated = true
	return true
	
static func prop_is_interpolated(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id] as WyncEntityProp
	return prop.interpolated

# server only
static func prop_set_timewarpable(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id] as WyncEntityProp
	prop.timewarpable = true
	prop.confirmed_states = RingBuffer.new(ctx.max_tick_history)
	return true

# server only
static func prop_is_timewarpable(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id] as WyncEntityProp
	return prop.timewarpable


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


static func is_entity_tracked(ctx: WyncCtx, entity_id: int) -> bool:
	return ctx.tracked_entities.has(entity_id)


# Interpolation / Extrapolation / Prediction functions
# ================================================================

## @returns tuple[int, int]. tick left, tick right
static func find_closest_two_snapshots_from_prop_id(ctx: WyncCtx, target_time: int, prop_id: int, co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData) -> Array:
	
	var prop = WyncUtils.get_prop(ctx, prop_id)
	if prop == null:
		return []
	
	return find_closest_two_snapshots_from_prop(
		ctx,
		target_time,
		ctx.props[prop_id] as WyncEntityProp,
		co_ticks,
		co_predict_data
	)


## @returns tuple[int, int]. tick left, tick right
static func find_closest_two_snapshots_from_prop(_ctx: WyncCtx, target_time: int, prop: WyncEntityProp, co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData) -> Array:
	
	var snap_left = -1
	var snap_right = -1
	
	for i in range(prop.last_ticks_received.size):
		var server_tick = prop.last_ticks_received.get_relative(-i)
		if server_tick is not int:
			continue

		# get snapshot from received ticks
		# NOTE: This block shouldn't necessary
		# TODO: before storing check the data is healthy
		#var data = prop.confirmed_states.get_at(server_tick)
		#if data == null:
			#continue

		# get local tick
		var arrived_at_tick = prop.arrived_at_tick.get_at(server_tick)
		if arrived_at_tick is not int:
			continue

		var snapshot_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, arrived_at_tick)

		if snapshot_timestamp > target_time:
			snap_right = server_tick
		elif snap_right != -1 && snapshot_timestamp < target_time:
			snap_left = server_tick
			break
	
	if snap_left == -1:
		return []
	
	return [snap_left, snap_right]


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
static func entity_get_sim_fun(ctx: WyncCtx, entity_id: int):# -> optional<Callable>
	if not ctx.entity_has_simulation_fun.has(entity_id):
		return null
	var sim_fun_id = ctx.entity_has_simulation_fun[entity_id]
	var sim_fun = ctx.simulation_functions[sim_fun_id]
	if sim_fun is not Callable:
		return null
	return sim_fun


## @returns optional<Callable>
static func entity_get_integrate_fun(ctx: WyncCtx, entity_id: int):# -> optional<Callable>
	if not ctx.entity_has_integrate_fun.has(entity_id):
		return null
	var sim_fun_id = ctx.entity_has_integrate_fun[entity_id]
	var sim_fun = ctx.simulation_functions[sim_fun_id]
	if sim_fun is not Callable:
		return null
	return sim_fun


static func prop_exists(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id < 0 || prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id]
	if prop is not WyncEntityProp:
		return false
	return true


## @returns Optional<WyncEntityProp>
static func get_prop(ctx: WyncCtx, prop_id: int) -> WyncEntityProp:
	if prop_id < 0 || prop_id > ctx.props.size() -1:
		return null
	var prop = ctx.props[prop_id]
	if prop is not WyncEntityProp:
		return null
	return prop


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
	ctx.client_owns_prop[client_id].append(prop_id)
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
	
	if !is_client(ctx):
		ctx.client_has_info[peer_id] = WyncClientInfo.new()
	return peer_id


static func server_setup(ctx: WyncCtx) -> int:
	# peer id 0 reserved for server
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
	WyncUtils.setup_peer_global_events(ctx, ctx.my_peer_id)
	for i in range(1, 2):
		WyncUtils.setup_peer_global_events(ctx, i)
	return 0
	

## Client side function

static func client_setup_my_client(ctx: WyncCtx, peer_id: int) -> bool:
	ctx.my_peer_id = peer_id
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
	
	# setup server global events
	WyncUtils.setup_peer_global_events(ctx, ctx.SERVER_PEER_ID)
	# setup own global events
	WyncUtils.setup_peer_global_events(ctx, ctx.my_peer_id)
	return true


## @returns int: peer_id if found; -1 if not found
static func is_peer_registered(ctx: WyncCtx, peer_data: int) -> int:
	for peer_id: int in range(ctx.peers.size()):
		var i_peer_data = ctx.peers[peer_id]
		if i_peer_data == peer_data:
			return peer_id
	return -1

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
	if (!ctx.connected):
		printerr("WyncUtils setup_client_global_events | not connected")
		return 1
	
	var entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS + peer_id
	WyncUtils.track_entity(ctx, entity_id)
	var channel_id = 0
	var prop_channel = WyncUtils.prop_register(
		ctx,
		entity_id,
		"channel_%d" % [channel_id],
		WyncEntityProp.DATA_TYPE.EVENT,
		func() -> Array: # getter
			return ctx.peer_has_channel_has_events[peer_id][channel_id].duplicate(true),
		func(input: Array): # setter
			var event_array = ctx.peer_has_channel_has_events[peer_id][channel_id] as Array
			event_array.clear()
			event_array.append_array(input),
	)
	if (WyncUtils.is_client(ctx) && peer_id == ctx.my_peer_id):
		WyncUtils.prop_set_predict(ctx, prop_channel)

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

static func is_client(ctx: WyncCtx, peer_id: int = -1) -> bool:
	if peer_id >= 0:
		return peer_id > 0
	return ctx.my_peer_id > 0


static func duplicate_any(any): #-> Optional<any>
	if any is Object:
		if any.has_method("copy"):
			return any.copy()
		if any.has_method("make_duplicate"):
			return any.make_duplicate()
		elif any.has_method("duplicate") && any is not Node:
			return any.duplicate()
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
