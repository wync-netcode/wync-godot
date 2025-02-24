class_name SyWyncLatestValue
extends System
const label: StringName = StringName("SyWyncLatestValue")

## sets props state to last confirmed received state
## NOTE: optimize which to reset, by knowing which were modified/new state gotten
## NOTE: reset only when new data is available

func _ready():
	components = [
		CoActor.label,
		CoActorRegisteredFlag.label,
		CoFlagWyncEntityTracked.label
	]
	super()


func on_process(entities, _data, _delta: float):
	var co_ticks = ECS.get_singleton_component(self, CoTicks.label) as CoTicks
	var co_predict_data = ECS.get_singleton_component(self, CoSingleNetPredictionData.label) as CoSingleNetPredictionData

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err(self, "Couldn't find singleton CoTransportLoopback")
		return
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext
	var wync_ctx = single_wync.ctx as WyncCtx
	
	# Reset all extrapolated entities to last confirmed tick
	# Don't affect predicted entities?
	# TODO: store props in HashMap instead of Array
	
	var prop_id_list: Array[int] = []
	var prop_id_list_delta_sync: Array[int] = []
	var prop_id_list_delta_sync_predicted: Array[int] = []
	for prop_id: int in wync_ctx.props.size():
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if !prop.just_received_new_state:
			continue
		prop.just_received_new_state = false

		if prop.relative_syncable:
			prop_id_list_delta_sync.append(prop_id)
			if WyncUtils.prop_is_predicted(wync_ctx, prop_id):
				prop_id_list_delta_sync_predicted.append(prop_id)
		else:
			prop_id_list.append(prop_id)
		
	# rest state to _canonic_

	reset_all_state_to_confirmed_tick_relative(wync_ctx, prop_id_list, 0)
	predicted_delta_props_rollback_to_canonic_state(wync_ctx, prop_id_list_delta_sync_predicted, co_ticks, co_predict_data)

	# apply newly received delta events to catch up to _canonic_
	
	delta_props_update_and_apply_delta_events(wync_ctx, prop_id_list_delta_sync)
	
	
	# call integration function to sync new transforms with physics server
	# NOTE: Maybe include in the filter if they actually are elligible to integrate
	
	var entity_id_list: Array[int] = []
	for entity: Entity in entities:
		var co_actor = entity.get_component(CoActor.label) as CoActor
		entity_id_list.append(co_actor.id)
	integrate_state(wync_ctx, entity_id_list)


#static func reset_all_state_to_confirmed_tick(wync_ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	#for prop_id: int in prop_ids:
		#var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		#if prop == null:
			#continue 
		#prop = prop as WyncEntityProp
		
		#var last_confirmed = prop.confirmed_states.get_at(tick)
		#if last_confirmed == null:
			#continue
		
		#prop.setter.call(last_confirmed.data)


static func reset_all_state_to_confirmed_tick_relative(wync_ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(wync_ctx, prop_id)
		if prop == null:
			continue 
		prop = prop as WyncEntityProp
		
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick) as int
		var last_confirmed = prop.confirmed_states.get_at(last_confirmed_tick)
		if last_confirmed == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(wync_ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		prop.setter.call(last_confirmed)


# should be run on client each logic frame
# applies delta events and keeps delta props healthy

static func delta_props_update_and_apply_delta_events(ctx: WyncCtx, prop_ids: Array[int]):

	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
	#Log.out(ctx, "SyWyncLatestValue | delta sync | delta_prop_ids %s" % [prop_ids])

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			Log.err(ctx, "SyWyncLatestValue | delta sync | couldn't find prop id(%s)" % [prop_id])
			continue 
		prop = prop as WyncEntityProp

		var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.err(ctx, "SyWyncLatestValue | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id])
			continue
		aux_prop = aux_prop as WyncEntityProp
		
		# NOTE: Are we sure we have delta_props_last_tick[prop_id]?
		if not delta_props_last_tick.has(prop_id):
			continue

		# FIXME: There will be UB if between the range before last_tick_received we didn't receive and input
		# resulting in usage of old values
		# apply events in order

		for tick: int in range(delta_props_last_tick[prop_id] +1, ctx.last_tick_received +1):
			var delta_event_list = aux_prop.confirmed_states.get_at(tick)
			if delta_event_list is not Array[int]:
				Log.err(ctx, "SyWyncLatestValue | delta sync | we don't have an input for this tick %s" % [tick])
				continue

			for event_id: int in delta_event_list:
				var err = WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

				# this error is almost fatal, should never happen, it could fail because of not finding the event
				# in that case we're gonna continue in hopes we eventually get the event data
				# TODO: implement measures against this ever happening
				if err:
					Log.err(ctx, "delta sync | VERY BAD, couldn't apply event id(%s) err(%s)" % [event_id, err])
					break
				Log.out(ctx, "delta sync | client consumed delta event %d" % [event_id])

			# update the latest tick we're at
			delta_props_last_tick[prop_id] = ctx.last_tick_received


static func predicted_delta_props_rollback_to_canonic_state \
	(ctx: WyncCtx, prop_ids: Array[int], co_ticks: CoTicks, co_predict_data: CoSingleNetPredictionData):

	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary
	#Log.out(ctx, "SyWyncLatestValue | delta sync | delta_prop_ids %s" % [prop_ids])

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			Log.err(ctx, "SyWyncLatestValue | delta sync | couldn't find prop id(%s)" % [prop_id])
			continue 
		prop = prop as WyncEntityProp

		# not checking if props are valid for this operation or not
		# that should be checked before passing prop_ids to this function

		var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.err(ctx, "SyWyncLatestValue | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id])
			continue
		aux_prop = aux_prop as WyncEntityProp
		
		# NOTE: Are we sure we have delta_props_last_tick[prop_id]?
		if not delta_props_last_tick.has(prop_id):
			continue

		var last_delta_prop_tick = delta_props_last_tick[prop_id]

		# apply events in order

		Log.out(ctx, "SyWyncLatestValue | server_ticks(%s) target_pred_tick(%s) last_delta_prop_tick(%s) last_tick_pred(%s)" % [
			co_ticks.server_ticks,
			co_predict_data.target_tick,
			last_delta_prop_tick,
			co_predict_data.delta_prop_last_tick_predicted,
		])
		for tick: int in range(co_predict_data.delta_prop_last_tick_predicted, last_delta_prop_tick, -1):

			var undo_event_id_list = aux_prop.confirmed_states_undo.get_at(tick)
			if undo_event_id_list == null || undo_event_id_list is not Array[int]:
				
				var local_tick = co_predict_data.get_tick_predicted(tick)
				
				# TODO: Tidy up this way of making sure there are no more predicted ticks
				# FIXME: This is gonna break when we introduce Prop Spawning
				
				var we_didnt_predict = local_tick == null || local_tick is not int
				if we_didnt_predict:
					# FIXME: There are gonna be older values used here, make sure to overwrite them
					# that's fine, stop here
					Log.out(ctx, "SyWyncLatestValue debug1 | didn't / haven't predicted this tick %s" % [tick])
					continue
				else: # we DID predict and there is NO cache
					Log.err(ctx, "SyWyncLatestValue | FATAL got an empty undo_event_id_list prop(%s) tick(%s)" % [prop_id, tick])
					assert(false)
					return
					
			undo_event_id_list = undo_event_id_list as Array[int]

			# merge state

			for event_id: int in undo_event_id_list:
				WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

				if not ctx.events.has(event_id):
					continue
				var event_data = (ctx.events[event_id] as WyncEvent).data
				Log.out(ctx, "SyWyncLatestValue | delta sync debug1 | applied undo_events predicted_tick(%s) %s %s" % [tick, undo_event_id_list, HashUtils.object_to_dictionary(event_data)])


static func integrate_state(wync_ctx: WyncCtx, wync_entity_ids: Array):
	
	# iterate all entities
	# check if they have a prop that was affected?
	# run entity integration function

	for entity_id: int in wync_entity_ids:
		
		if not wync_ctx.entity_has_props.has(entity_id):
			continue
				
		var int_fun = WyncUtils.entity_get_integrate_fun(wync_ctx, entity_id)
		if int_fun is Callable:
			int_fun.call()
