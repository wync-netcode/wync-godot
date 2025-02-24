class_name SyWyncXtrap
extends System
const label: StringName = StringName("SyWyncXtrap")

## Extrapolates / Predicts the position

func _ready():
	components = [
		CoActor.label,
		CoActorRegisteredFlag.label,
		CoFlagWyncEntityTracked.label
	]
	super()


func on_process(entities, _data, delta: float):

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return
	
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx

	var target_tick = co_predict_data.target_tick
	
	# get physics space to later sync transforms to physics server
	# sync physics after 'SyWyncLatestValue'
	
	var space := get_viewport().world_2d.space
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)

	# prediction loop
	# FIXME: using last_confirmed_tick is UB
	# FIXME: not all props will have the same 'last_confirmed_tick'

	var last_confirmed_tick = wync_ctx.last_tick_received
	if last_confirmed_tick == 0:
		return

	wync_ctx.currently_on_predicted_tick = true
	# NOTE: defer: wync_ctx.currently_on_predicted_tick = false
	
	# We can detect a local_tick is duplicated by checking is the same as te previous,
	# Then we can honor the config wheter to allow duplication or not for each prop
	var is_local_tick_duplicated = false
	var prev_local_tick: Variant = null # Optional<int>
	var local_tick: Variant = null # Optional<int>
	
	for tick in range(last_confirmed_tick +1, target_tick +1):
		wync_ctx.current_predicted_tick = tick
		
		# set events inputs to corresponding value depending on tick
		# --------------------------------------------------
		# ALL INPUT/EVENT PROPS, no excepcion for now
		# TODO: identify which I own and which belong to my foes'
		
		prev_local_tick = local_tick
		local_tick = co_predict_data.get_tick_predicted(tick)
		if local_tick == null || local_tick is not int:
			continue
		is_local_tick_duplicated = prev_local_tick == local_tick
		
		for prop_id: int in range(wync_ctx.props.size()):
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			if prop == null:
				continue
			if not WyncUtils.prop_is_predicted(wync_ctx, prop_id):
				continue
			if prop.data_type not in [WyncEntityProp.DATA_TYPE.INPUT,
				WyncEntityProp.DATA_TYPE.EVENT]:
				continue
		
			# using local_tick for predicted states INPUT,EVENT
			var input_snap = prop.confirmed_states.get_at(local_tick)
			# honor no duplication
			if (prop.data_type == WyncEntityProp.DATA_TYPE.EVENT
				&& is_local_tick_duplicated):

				if (not prop.allow_duplication_on_tick_skip):

					# set default value, in the future we might support INPUT type as well
					input_snap = [] as Array[int]
				
			if input_snap == null:
				continue
			
			prop.setter.call(input_snap)
			# INPUT/EVENTs don't need integration functions

		# clearing delta events before predicting, predicted delta events will be
		# polled and cached at the end of the predicted tick
		SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(wync_ctx)
		
		# START USER PREDICTION FUNCTIONS --------------------------------------
		# Prediction / Extrapolation:
		# Run user provided simulation functions
		# TODO: Better way to receive simulate functions?
		
		for entity: Entity in entities:
		
			var co_actor = entity.get_component(CoActor.label) as CoActor
			if !WyncUtils.entity_is_predicted(wync_ctx, co_actor.id):
				continue
			
			if ECS.entity_has_system_components(entity.id, SyActorMovement.label):
				SyActorMovement.simulate_movement(entity, delta)
				SyActorMovement.simulate_particle_on_start_moving(entity, delta, tick)
			if ECS.entity_has_system_components(entity.id, SyBallMovement.label):
				SyBallMovement.simulate_movement(entity, delta)

		# Prediction functions that do their own looping
		
		SyActorEvents.client_simulate_events(self)
		
		# END USER PREDICTION FUNCTIONS ----------------------------------------
		
		# wync bookkeeping
		# --------------------------------------------------

		for entity: Entity in entities:
		
			var co_actor = entity.get_component(CoActor.label) as CoActor
			if !WyncUtils.entity_is_predicted(wync_ctx, co_actor.id):
				continue
			
			# store predicted states
			# (run on last two iterations)
			
			if tick > (target_tick -1):
				props_update_predicted_states_data(wync_ctx, wync_ctx.entity_has_props[co_actor.id])
				
			# debug player trail
			
			if tick == target_tick || tick == last_confirmed_tick +1:
				var progress = (float(tick) - last_confirmed_tick) / (target_tick - last_confirmed_tick)
				var prop_position = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "position")
				if prop_position:
					DebugPlayerTrail.spawn(self, prop_position.getter.call(), progress)

			# integration functions
			
			var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
			if int_fun is Callable:
				int_fun.call()

			# update/store predicted state metadata
		
			props_update_predicted_states_ticks(wync_ctx, wync_ctx.entity_has_props[co_actor.id], target_tick)
		
		# extract / poll for generated predicted _undo delta events_
		
		for prop_id: int in range(wync_ctx.props.size()):
			var prop = WyncUtils.get_prop(wync_ctx, prop_id)
			if prop == null:
				continue
			prop = prop as WyncEntityProp
			if not prop.relative_syncable:
				continue
			if not WyncUtils.prop_is_predicted(wync_ctx, prop_id):
				continue
				
			var aux_prop = WyncUtils.get_prop(wync_ctx, prop.auxiliar_delta_events_prop_id)
			if aux_prop == null:
				continue
			aux_prop = aux_prop as WyncEntityProp
			
			var undo_events = aux_prop.current_undo_delta_events.duplicate(true)
			aux_prop.confirmed_states_undo.insert_at(tick, undo_events)
		
		# sync transforms to physics server
		RapierPhysicsServer2D.space_step(space, 0)
		RapierPhysicsServer2D.space_flush_queries(space)

	SyWyncTickStartAfter.auxiliar_props_clear_current_delta_events(wync_ctx)
	co_predict_data.delta_prop_last_tick_predicted = target_tick

	# "defer"
	wync_ctx.currently_on_predicted_tick = false


static func props_update_predicted_states_data(ctx: WyncCtx, props_ids: Array) -> void:
	
	for prop_id: int in props_ids:
		
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop == null:
			continue

		var pred_curr = prop.pred_curr
		var pred_prev = prop.pred_prev
		
		# Initialize stored predicted states. TODO: Move elsewhere
		
		if pred_curr.data == null:
			pred_curr.data = Vector2.ZERO
			pred_prev = pred_curr.copy()
			continue
			
		# store predicted states
		# (run on last two iterations)
		
		pred_prev.data = pred_curr.data
		pred_curr.data = prop.getter.call()


static func props_update_predicted_states_ticks(ctx: WyncCtx, props_ids: Array, target_tick: int) -> void:
	
	for prop_id: int in props_ids:
		
		var prop = ctx.props[prop_id] as WyncEntityProp
		if prop == null:
			continue

		# update store predicted state metadata
		
		prop.pred_prev.server_tick = target_tick -1
		prop.pred_curr.server_tick = target_tick
