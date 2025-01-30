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
	prop.interpolated = true
	return true
	
static func prop_is_interpolated(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id] as WyncEntityProp
	return prop.interpolated

static func prop_set_push_to_global_event(ctx: WyncCtx, prop_id: int, channel: int) -> int:
	if prop_id > ctx.props.size() -1:
		return 1
	var prop = ctx.props[prop_id] as WyncEntityProp
	prop.push_to_global_event = true
	prop.global_event_channel = channel
	return 0

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


## @returns tuple[NetTickData, NetTickData]
static func find_closest_two_snapshots_from_prop_id(ctx: WyncCtx, target_time: int, prop_id: int, co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData) -> Array:
	
	if prop_id > ctx.props.size() -1:
		return []
	
	return find_closest_two_snapshots_from_prop(
		target_time,
		ctx.props[prop_id] as WyncEntityProp,
		co_ticks,
		co_predict_data
	)


## @returns tuple[NetTickData, NetTickData]
static func find_closest_two_snapshots_from_prop(target_time: int, prop: WyncEntityProp, co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData) -> Array:

	var ring = prop.confirmed_states
	
	var snap_left: NetTickData = null
	var snap_right: NetTickData = null
	
	for i in range(ring.size):
		var snapshot = ring.get_relative(-i) as NetTickData
		if not snapshot:
			break
		var snapshot_timestamp = ClockUtils.get_tick_local_time_msec(co_predict_data, co_ticks, snapshot.arrived_at_tick)

		if snapshot_timestamp > target_time:
			snap_right = snapshot
		elif snap_right != null && snapshot_timestamp < target_time:
			snap_left = snapshot
			break
	
	if snap_left == null:
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


static func prop_set_client_owner(ctx: WyncCtx, prop_id: int, client_id: int) -> bool:
	# NOTE: maybe don't check because this prop could be synced later
	#if not prop_exists(ctx, prop_id):
		#return false
	ctx.client_owns_prop[client_id].append(prop_id)
	return true


# Setup functions
# ================================================================

static func server_setup(ctx: WyncCtx) -> int:
	# peer id 0 reserved for server
	ctx.my_peer_id = 0
	ctx.peers.resize(1)
	ctx.peers[ctx.my_peer_id] = -1
	ctx.connected = true
	WyncUtils.setup_global_events(ctx)
	return 0
	

## Server side function
## @argument peer_data (optional): store a custom int if needed. Use it to save an external identifier. This is usually the transport's peer_id
 
static func peer_register(ctx: WyncCtx, peer_data: int = -1) -> int:
	var peer_id = ctx.peers.size()
	ctx.peers.append(peer_data)
	ctx.client_owns_prop[peer_id] = []
	return peer_id

## Client side function

static func client_setup_my_client(ctx: WyncCtx, peer_id: int) -> bool:
	ctx.my_peer_id = peer_id
	ctx.client_owns_prop[peer_id] = []

	ctx.events_hash_to_id.init(WyncCtx.MAX_AMOUNT_CACHE_EVENTS)
	ctx.events_sent.init(WyncCtx.MAX_AMOUNT_CACHE_EVENTS)
	WyncUtils.setup_global_events(ctx)
	return true


## @returns int: peer_id if found; -1 if not found
static func is_peer_registered(ctx: WyncCtx, peer_data: int) -> int:
	for peer_id: int in range(ctx.peers.size()):
		var i_peer_data = ctx.peers[peer_id]
		if i_peer_data == peer_data:
			return peer_id
	return -1


static func setup_global_events(ctx: WyncCtx) -> int:
	ctx.global_events_channel.resize(WyncCtx.MAX_GLOBAL_EVENT_CHANNELS)
	print("GlobalEvent | %s" % [ctx.global_events_channel])

	var entity_id = WyncCtx.ENTITY_ID_GLOBAL_EVENTS
	WyncUtils.track_entity(ctx, entity_id)

	var prop_channel_0 = WyncUtils.prop_register(
		ctx,
		entity_id,
		"channel_0",
		WyncEntityProp.DATA_TYPE.EVENT,
		func(): return [],
		func(input: Array):
			ctx.global_events_channel[0].clear()
			ctx.global_events_channel[0].append_array(input),
	)
	if (WyncUtils.is_client(ctx)):
		WyncUtils.prop_set_predict(ctx, prop_channel_0)

	return 0


# Loop functions: Functions or 'systems' that are intented to run on the game loops
# ================================================================

## extract events from props DATA_TYPE.EVENT global
## and inserts/duplicates them into the ctx.global_events_channel

static func system_publish_global_events(ctx: WyncCtx, tick: int) -> void:
	
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
		input = input as Array
		ctx.global_events_channel[prop.global_event_channel].append_array(input)


# Miscellanious
# ================================================================

static func duplicate_any(any): #-> Optional<any>
	if any is Object:
		if any.has_method("copy"):
			return any.copy()
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


static func is_client(ctx: WyncCtx) -> bool:
	return ctx.my_peer_id > 0
