class_name SyWyncXtrap
extends System
const label: StringName = StringName("SyWyncXtrap")

## Extrapolates the position

func _ready():
	components = [
		CoActor.label,
		#CoBall.label,
		#CoFlagNetExtrapolate.label,
		CoNetConfirmedStates.label,
		CoNetPredictedStates.label, 
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

	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var target_tick = co_predict_data.target_tick
	var last_confirmed_tick = 0
	
	# Don't affect unwanted entities
	# reset all extrapolated entities to last confirmed tick
		
	for entity: Entity in entities:
		
		var co_actor = entity.get_component(CoActor.label) as CoActor
		
		if not wync_ctx.entity_has_props.has(co_actor.id):
			continue
		
		for prop_id: int in wync_ctx.entity_has_props[co_actor.id]:
			
			var prop = wync_ctx.props[prop_id] as WyncEntityProp
			if prop == null:
				continue
			
			
			var last_confirmed = prop.confirmed_states.get_relative(0) as NetTickData

			
			if last_confirmed == null:
				continue
			if last_confirmed.data == null:
				continue
			
			
			prop.setter.call(last_confirmed.data)
			
			last_confirmed_tick = max(last_confirmed_tick, last_confirmed.tick)
		
		# call integration function to sync new transforms with physics server
				
		var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
		int_fun.call()
	
	# sync transforms to physics server
	var space := get_viewport().world_2d.space
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)

	# predict them back
	
	#Log.out(self, "Predicting back entities here")
	
	for tick in range(last_confirmed_tick +1, target_tick +1):
		
		for entity: Entity in entities:
			
			var co_actor = entity.get_component(CoActor.label) as CoActor
			if not wync_ctx.entity_has_props.has(co_actor.id):
				continue
			
			# set input to correct value
			
			#wync_set_input_to_tick_value()
			var input_prop = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "input")
			if input_prop != null:
				if input_prop.data_type == WyncEntityProp.DATA_TYPE.INPUT:
					var local_tick = co_predict_data.get_tick_predicted(tick)
					if local_tick == null:
						continue
					var input_snap = input_prop.confirmed_states.get_at(local_tick)
					input_prop.setter.call(input_snap)
					#print(input_snap)
					#print(input_snap.aim)
					#print(1)
					#if las

			# get simulation function
				
			var sim_fun = WyncUtils.entity_get_sim_fun(wync_ctx, co_actor.id)
			if sim_fun is not Callable: 
				# NOTE: no need to check this, all these props should have it, make sure to secure data integrity
				continue
		
			# predict ticks

			sim_fun.call(entity, delta)
			#Log.out(self, "simulating entity %s" % co_actor.id)
			
			# store predicted states
			# (run on last two iterations)
			
			if tick > (target_tick -1):
				props_update_predicted_states_data(wync_ctx, wync_ctx.entity_has_props[co_actor.id])
				
			# debug player trail
			
			var progress = (float(tick) - last_confirmed_tick) / (target_tick - last_confirmed_tick)
			var prop_position = WyncUtils.entity_get_prop(wync_ctx, co_actor.id, "position")
			if prop_position:
				if tick == target_tick || tick == last_confirmed_tick +1:
					DebugPlayerTrail.spawn(self, prop_position.getter.call(), progress)

		# update store predicted state metadata
		
		for entity: Entity in entities:
			
			var co_actor = entity.get_component(CoActor.label) as CoActor
			if not wync_ctx.entity_has_props.has(co_actor.id):
				continue
			
			var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, co_actor.id)
			int_fun.call()
		
			props_update_predicted_states_ticks(wync_ctx, wync_ctx.entity_has_props[co_actor.id], target_tick)
		
		# sync transforms to physics server
		RapierPhysicsServer2D.space_step(space, 0)
		RapierPhysicsServer2D.space_flush_queries(space)


#static func props_update_predicted_states_ticks

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

		var pred_curr = prop.pred_curr
		var pred_prev = prop.pred_prev

		# update store predicted state metadata
		
		pred_prev.tick = target_tick -1
		pred_curr.tick = target_tick
