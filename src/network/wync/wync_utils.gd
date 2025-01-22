class_name WyncUtils

# Entity / Property functions
# ================================================================


static func track_entity(ctx: WyncCtx, entity_id: int):
	ctx.tracked_entities.append(entity_id)
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


## @argument client_data (optional): store a custom int if needed. Use it to save an external identifier.
 
static func client_register(ctx: WyncCtx, client_data: int = -1) -> int:
	var client_id = ctx.clients.size()
	ctx.clients.append(client_data)
	ctx.client_owns_prop[client_id] = []
	return client_id


static func client_setup_my_client(ctx: WyncCtx, client_id: int) -> bool:
	ctx.my_client_id = client_id
	ctx.client_owns_prop[client_id] = []
	return true


## @returns int: client_id if found; -1 if not found
static func is_client_registered(ctx: WyncCtx, client_data: int) -> int:
	#return client_id >= 0 && client_id < ctx.clients.size()
	for client_id: int in range(ctx.clients.size()):
		var i_client_data = ctx.clients[client_id]
		if i_client_data == client_data:
			return client_id
	return -1


static func prop_exists(ctx: WyncCtx, prop_id: int) -> bool:
	if prop_id < 0 || prop_id > ctx.props.size() -1:
		return false
	var prop = ctx.props[prop_id]
	if prop is not WyncEntityProp:
		return false
	return true


static func prop_set_client_owner(ctx: WyncCtx, prop_id: int, client_id: int) -> bool:
	if not prop_exists(ctx, prop_id):
		return false
	ctx.client_owns_prop[client_id].append(prop_id)
	return true
