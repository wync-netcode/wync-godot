class_name UserWyncUtils


# --------------------------------------------------------------------------------
# WYNC ENTITY SETUPS
# --------------------------------------------------------------------------------


static func setup_entity_type(node_ctx: Node, entity: Entity, entity_type_id: int):

	match entity_type_id:
		GameInfo.ENTITY_TYPE_BALL:
			setup_entity_ball(node_ctx, entity)
		GameInfo.ENTITY_TYPE_PLAYER:
			setup_entity_player(node_ctx, entity)
		GameInfo.ENTITY_TYPE_GRID_PREDICTED:
			setup_entity_block_grid_predicted(node_ctx, entity)
		GameInfo.ENTITY_TYPE_GRID_DELTA:
			setup_entity_block_grid_delta(node_ctx, entity, false)
		GameInfo.ENTITY_TYPE_GRID_DELTA_PREDICTED:
			setup_entity_block_grid_delta(node_ctx, entity, true)
		GameInfo.ENTITY_TYPE_PROJECTILE:
			setup_entity_rocket(node_ctx, entity)
		_:
			Log.err("setup_entity_type entity_type_id(%s) not recognized" % [entity_type_id])

	var flag = CoFlagWyncEntityTracked.new()
	ECS.entity_add_component_node(entity, flag)


static func setup_entity_ball(node_ctx: Node, entity: Entity):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_ball = entity.get_component(CoBall.label) as CoBall
	var co_collider = entity.get_component(CoCollider.label) as CharacterBody2D
	
	WyncUtils.track_entity(wync_ctx, co_actor.id, GameInfo.ENTITY_TYPE_BALL)
	var pos_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func() -> Vector2: return co_collider.global_position,
		func(pos: Vector2): co_collider.global_position = pos,
	)
	var vel_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"velocity",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func() -> Vector2: return co_collider.velocity,
		func(vel: Vector2): co_collider.velocity = vel,
	)
	var aim_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"aim",
		WyncEntityProp.DATA_TYPE.FLOAT,
		func() -> float: return co_ball.aim_radians,
		func(new_aim: float): co_ball.aim_radians = new_aim,
	)
	
	# integration function

	var int_fun_id = WyncUtils.register_function(wync_ctx, co_collider.force_update_transform)
	if int_fun_id < 0:
		Log.err("Couldn't register integrate fun", Log.TAG_PROP_SETUP)
	else:
		WyncUtils.entity_set_integration_fun(wync_ctx, co_actor.id, int_fun_id)
	
	if WyncUtils.is_client(wync_ctx):
		# interpolation
		
		WyncUtils.prop_set_interpolate(wync_ctx, pos_prop_id)
		WyncUtils.prop_set_interpolate(wync_ctx, vel_prop_id)
		WyncUtils.prop_set_interpolate(wync_ctx, aim_prop_id)
		
		# setup extrapolation

		if co_actor.id % 2 == 0:
			WyncUtils.prop_set_predict(wync_ctx, pos_prop_id)
			WyncUtils.prop_set_predict(wync_ctx, vel_prop_id)
	
	# it is server
	else:
		
		# time warp
		WyncUtils.prop_set_timewarpable(wync_ctx, pos_prop_id) 


static func setup_entity_rocket(node_ctx: Node, entity: Entity):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	var co_actor = entity.get_component(CoActor.label) as CoActor
	var entity_node = entity as Node as Node2D
	
	WyncUtils.track_entity(wync_ctx, co_actor.id, GameInfo.ENTITY_TYPE_PROJECTILE)
	var pos_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func() -> Vector2: return entity_node.global_position,
		func(pos: Vector2): entity_node.global_position = pos,
	)
	
	# interpolation

	if WyncUtils.is_client(wync_ctx):
		WyncUtils.prop_set_interpolate(wync_ctx, pos_prop_id)


static func setup_entity_player(node_ctx: Node, entity: Entity):

	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
		
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_collider = entity.get_component(CoCollider.label) as CharacterBody2D
	var co_actor_input = entity.get_component(CoActorInput.label) as CoActorInput
	var co_wync_events = entity.get_component(CoWyncEvents.label) as CoWyncEvents
	
	# NOTE: Register just the ball for now
	
	WyncUtils.track_entity(wync_ctx, co_actor.id, GameInfo.ENTITY_TYPE_PLAYER)
	var pos_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"position",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func() -> Vector2: return co_collider.global_position,
		func(pos: Vector2): co_collider.global_position = pos,
	)
	var vel_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"velocity",
		WyncEntityProp.DATA_TYPE.VECTOR2,
		func() -> Vector2: return co_collider.velocity,
		func(vel: Vector2): co_collider.velocity = vel,
	)
	var input_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"input",
		WyncEntityProp.DATA_TYPE.INPUT,
		func() -> CoActorInput.PortableCopy: return co_actor_input.copy(),
		func(input: CoActorInput.PortableCopy): co_actor_input.set_from_instance(input),
	)
	
	# We're gonna be using this prop to store "shoot" events for TimeWarping
	# or subtick precision
	var events_prop_id = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"events",
		WyncEntityProp.DATA_TYPE.EVENT,
		func():
			return co_wync_events.events.duplicate(true),
		func(events: Array):
			co_wync_events.events.clear()
			# NOTE: can't check cast like this `if events is not Array[int]:`
			co_wync_events.events.append_array(events),
	)
	co_wync_events.prop_id = events_prop_id
		
	# integration function

	var int_fun_id = WyncUtils.register_function(wync_ctx, co_collider.force_update_transform)
	if int_fun_id < 0:
		Log.err("Couldn't register integrate fun", Log.TAG_PROP_SETUP)
	else:
		WyncUtils.entity_set_integration_fun(wync_ctx, co_actor.id, int_fun_id)

	if WyncUtils.is_client(wync_ctx):
		# interpolation
		
		WyncUtils.prop_set_interpolate(wync_ctx, pos_prop_id)
		WyncUtils.prop_set_interpolate(wync_ctx, vel_prop_id)
	
		# setup extrapolation
			
		WyncUtils.prop_set_predict(wync_ctx, pos_prop_id)
		WyncUtils.prop_set_predict(wync_ctx, vel_prop_id)
		WyncUtils.prop_set_predict(wync_ctx, input_prop_id)
		WyncUtils.prop_set_predict(wync_ctx, events_prop_id)
	
	# it is server
	else:
		
		# time warp
		WyncUtils.prop_set_timewarpable(wync_ctx, pos_prop_id) 


static func setup_entity_block_grid_predicted(node_ctx: Node, entity: Entity):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	
	# TODO: Move this elsewhere
	# Setup random blocks on server
	if !WyncUtils.is_client(wync_ctx):
		co_block_grid.generate_random_blocks()
	
	WyncUtils.track_entity(wync_ctx, co_actor.id, GameInfo.ENTITY_TYPE_GRID_PREDICTED)
	var _blocks_prop = WyncUtils.prop_register(
		wync_ctx,
		co_actor.id,
		"blocks",
		WyncEntityProp.DATA_TYPE.ANY,
		func() -> CoBlockGrid: return co_block_grid.make_duplicate(),
		func(block_grid: CoBlockGrid): co_block_grid.set_from_instance(block_grid),
	)
	
	Log.out("wync: Registered entity %s with id %s" % [entity, co_actor.id], Log.TAG_PROP_SETUP, Log.TAG_DEBUG2)


static func setup_entity_block_grid_delta(node_ctx: Node, entity: Entity, predicted: bool):
	var single_wync = ECS.get_singleton_component(node_ctx, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	if !wync_ctx.connected:
		return
	
	var co_actor = entity.get_component(CoActor.label) as CoActor
	var co_block_grid = entity.get_component(CoBlockGrid.label) as CoBlockGrid
	var wync_entity_id = co_actor.id
	
	# TODO: Move this elsewhere
	# Setup random blocks on server
	if not WyncUtils.is_client(wync_ctx):
		co_block_grid.generate_random_blocks()

	# setup props
	
	WyncUtils.track_entity(wync_ctx, wync_entity_id, GameInfo.ENTITY_TYPE_GRID_DELTA)
	var blocks_prop = WyncUtils.prop_register(
		wync_ctx,
		wync_entity_id,
		"blocks",
		WyncEntityProp.DATA_TYPE.ANY,
		func() -> CoBlockGrid: return co_block_grid.make_duplicate(),
		func(block_grid: CoBlockGrid): co_block_grid.set_from_instance(block_grid),
	)

	# hook Prop to Blueprint

	var err = WyncDeltaSyncUtils.prop_set_relative_syncable(
		wync_ctx,
		wync_entity_id,
		blocks_prop,
		GameInfo.BLUEPRINT_ID_BLOCK_GRID_DELTA,
		func() -> CoBlockGrid: return co_block_grid,
		predicted
	)
	if err > 0:
		Log.err("Couldn't set relative sync to Prop id(%s) err(%s)" % [blocks_prop, err], Log.TAG_PROP_SETUP)
		return

	# required to extract state on start

	#WyncDeltaSyncUtils.delta_sync_prop_extract_state(wync_ctx, blocks_prop)
	
	Log.out("wync: Registered entity %s with id %s" % [entity, co_actor.id], Log.TAG_PROP_SETUP, Log.TAG_DEBUG2)


# --------------------------------------------------------------------------------
# BLUEPRINTS
# --------------------------------------------------------------------------------


static func setup_blueprints(ctx: WyncCtx):

	# setup relative synchronization blueprints

	var blueprint_id = WyncDeltaSyncUtils.create_delta_blueprint(ctx)
	WyncDeltaSyncUtils.delta_blueprint_register_event(
		ctx,
		blueprint_id,
		GameInfo.EVENT_DELTA_BLOCK_REPLACE,
		blueprint_handle_event_delta_block_replace
	)
	GameInfo.BLUEPRINT_ID_BLOCK_GRID_DELTA = blueprint_id


# Remember that these delta changes ARE NOT EVENTS but just changes over time.

# 'first time' is another name for 'requires_undo'
# 'wync_ctx' will only be set if 'requires_undo' is
# (state: Variant, event: WyncEvent.EventData, requires_undo: bool, ctx: WyncCtx*) -> [err, undo_event_id]:

## @returns Tuple[int, int]. [0] -> Error, [1] -> undo_event_id
static func blueprint_handle_event_delta_block_replace \
	(state: Variant, event: WyncEvent.EventData, requires_undo: bool, ctx: WyncCtx) -> Array[int]:

	# first: perform data checks / logical checks
	# Cast data to correct type
	# TODO: Maybe also tell me the data_type that is stored in the prop.

	if state is not CoBlockGrid:
		Log.err("EVENT_DELTA_BLOCK_REPLACE | Data is not CoBlockGrid", Log.TAG_DELTA_EVENT)
		return [1, -1]
	var co_block_grid = state as CoBlockGrid
	var block_pos = event.arg_data[0] as Vector2i
	var block_type = event.arg_data[1] as CoBlockGrid.BLOCK

	# Shouldn't need to check because the user was who submitted the event
	# But let's do it anyway to be safe

	if not (MathUtils.is_between_int(block_pos.x, 0, co_block_grid.LENGTH -1)
	&& MathUtils.is_between_int(block_pos.y, 0, co_block_grid.LENGTH -1)):
		Log.err("EVENT_DELTA_BLOCK_REPLACE | block_pos %s is invalid" % [block_pos], Log.TAG_DELTA_EVENT)
		return [1, -1]

	var block_data = co_block_grid.blocks[block_pos.x][block_pos.y] as CoBlockGrid.BlockData

	# secondly: create undo event (only required for prediction)

	var event_id = -1
	if requires_undo:
		var prev_block_type = block_data.id

		event_id = WyncEventUtils.instantiate_new_event(ctx, GameInfo.EVENT_DELTA_BLOCK_REPLACE, 2)
		WyncEventUtils.event_add_arg(ctx, event_id, 0, WyncEntityProp.DATA_TYPE.VECTOR2, block_pos)
		WyncEventUtils.event_add_arg(ctx, event_id, 1, WyncEntityProp.DATA_TYPE.INT, prev_block_type)
		event_id = WyncEventUtils.event_wrap_up(ctx, event_id)
		if (event_id == null):
			Log.err("EVENT_DELTA_BLOCK_REPLACE | Error couldn't wrap up event", Log.TAG_DELTA_EVENT)

	# finally: modify state

	block_data.id = block_type

	return [OK, event_id]
