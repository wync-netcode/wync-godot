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

	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var ctx = single_wync.ctx as WyncCtx
	var target_tick = ctx.co_predict_data.target_tick

	# get physics space to later sync transforms to physics server
	# sync physics after 'SyWyncLatestValue'
	
	var space := get_viewport().world_2d.space
	RapierPhysicsServer2D.space_step(space, 0)
	RapierPhysicsServer2D.space_flush_queries(space)

	if WyncXtrap.wync_xtrap_preparation(ctx) != OK:
		return

	WyncXtrap.wync_xtrap_tick_init_cache(ctx)
	#WyncXtrap.auxiliar_props_clear_current_delta_events_cache(ctx)
	WyncXtrap.wync_xtrap_tick_end_cache(ctx)

	for tick in range(ctx.pred_intented_first_tick - ctx.max_prediction_tick_threeshold, target_tick +1):

		WyncXtrap.wync_xtrap_tick_init(ctx, tick)
		var dont_predict_entity_ids = WyncXtrap.wync_xtrap_dont_predict_entities(ctx, tick)

		# ------- START USER PREDICTION FUNCTIONS -------
		# All state modified here is Predicted / Extrapolated
		
		for entity: Entity in entities:

			var co_actor = entity.get_component(CoActor.label) as CoActor
			if dont_predict_entity_ids.has(co_actor.id):
				continue

			#if !WyncUtils.entity_is_predicted(ctx, co_actor.id):
				#continue
			#if ECS.entity_has_system_components(entity.id, SyActorMovement.label):
			if co_actor.id == 0:
				SyActorMovement.simulate_movement(entity, delta)
				SyActorMovement.simulate_particle_on_start_moving(entity, delta, tick)
			if co_actor.id == 2:
			#if ECS.entity_has_system_components(entity.id, SyBallMovement.label):
				SyBallMovement.simulate_movement(entity, delta)
		
		# NOTE: This is also valid,
		# it's equivalent to telling the user to NOT predict these specifics entities
		# delta props shouldn't be repredicted because we only _rollback_ from the oficial pred start tick
		if tick >= ctx.pred_intented_first_tick:
			SyActorEvents.client_simulate_events(self)
		
		# debug: show a player trail

		for entity: Entity in entities:
			var co_actor = entity.get_component(CoActor.label) as CoActor
			if !WyncUtils.entity_is_predicted(ctx, co_actor.id):
				continue

			# (a). with condition: simple single trail
			# (b). without condition: long trail
			#if tick == target_tick || tick == ctx.pred_intented_first_tick:
			var progress = (float(tick) - ctx.last_tick_received) / (target_tick - ctx.last_tick_received)
			var prop_position = WyncUtils.entity_get_prop(ctx, co_actor.id, "position")
			if prop_position:
				DebugPlayerTrail.spawn(self, prop_position.getter.call(prop_position.user_ctx_pointer), progress, 0, false, -10)

		# ------- END USER PREDICTION FUNCTIONS -------

		WyncXtrap.wync_xtrap_tick_end(ctx, tick)

		# sync transforms to physics server
		RapierPhysicsServer2D.space_step(space, 0)
		RapierPhysicsServer2D.space_flush_queries(space)
		pass

	WyncXtrap.wync_xtrap_termination(ctx)
