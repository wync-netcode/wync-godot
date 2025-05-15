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


func on_process(_entities, _data, _delta: float):
	
	var single_wync = ECS.get_singleton_component(self, CoSingleWyncContext.label) as CoSingleWyncContext

	var co_loopback = GlobalSingletons.singleton.get_component(CoTransportLoopback.label) as CoTransportLoopback
	if not co_loopback:
		Log.err("Couldn't find singleton CoTransportLoopback", Log.TAG_LATEST_VALUE)
		return
	wync_reset_props_to_latest_value (single_wync.ctx)
	
	
static func wync_reset_props_to_latest_value (ctx: WyncCtx):
	var co_ticks = ctx.co_ticks
	var co_predict_data = ctx.co_predict_data
	
	# Reset all extrapolated entities to last confirmed tick
	# Don't affect predicted entities?
	# TODO: store props in HashMap instead of Array
	
	var prop_id_list: Array[int] = []
	var prop_id_list_delta_sync: Array[int] = []
	var prop_id_list_delta_sync_predicted: Array[int] = []
	for prop_id: int in ctx.props.size():
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp

		# these are set on prediction tick start
		if prop.data_type in [WyncEntityProp.DATA_TYPE.EVENT, WyncEntityProp.DATA_TYPE.INPUT]:
			continue

		if prop.relative_syncable:
			prop_id_list_delta_sync.append(prop_id)
			if WyncUtils.prop_is_predicted(ctx, prop_id):
				prop_id_list_delta_sync_predicted.append(prop_id)
		else:
			if prop.just_received_new_state || WyncUtils.prop_is_predicted(ctx, prop_id):
				prop.just_received_new_state = false
				prop_id_list.append(prop_id)
		
	# rest state to _canonic_

	#Log.outc(ctx, "debug_pred_delta_event LATEST START")

	reset_all_state_to_confirmed_tick_relative(ctx, prop_id_list, 0)
	predicted_delta_props_rollback_to_canonic_state(ctx, prop_id_list_delta_sync_predicted, co_ticks, co_predict_data)

	#Log.outc(ctx, "debug_pred_delta_event LATEST END")
	
	# --------------------------------------------------------------------------------
	# debugging: compare states
	for prop_id: int in range(ctx.props.size()):
		if prop_id != 15:
			continue
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.relative_syncable || not WyncUtils.prop_is_predicted(ctx, prop_id):
			continue
		var restored = WyncUtils.duplicate_any(prop.getter.call())
		var canonic = prop.confirmed_states.get_at(0)
		if restored == null || canonic == null:
			break

		var restored_str := JsonClassConverter.class_to_json_string(restored)
		var canonic_str := JsonClassConverter.class_to_json_string(canonic)

		if restored_str != canonic_str:
			assert(false)


	# --------------------------------------------------------------------------------

	# apply newly received delta events to catch up to _canonic_
	
	delta_props_update_and_apply_delta_events(ctx, prop_id_list_delta_sync)

	# --------------------------------------------------------------------------------
	# debugging: save the canonic state to later compare it with the rollback
	for prop_id: int in range(ctx.props.size()):
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue
		prop = prop as WyncEntityProp
		if not prop.relative_syncable || not WyncUtils.prop_is_predicted(ctx, prop_id):
			continue
		var state_dup = WyncUtils.duplicate_any(prop.getter.call())
		prop.confirmed_states.insert_at(0, state_dup)
	# --------------------------------------------------------------------------------
	
	
	# call integration function to sync new transforms with physics server
	# NOTE: Maybe include in the filter if they actually are elligible to integrate
	
	var entity_id_list: Array[int] = []
	
	for wync_entity_id: int in ctx.tracked_entities.keys():
		entity_id_list.append(wync_entity_id as int)

	integrate_state(ctx, entity_id_list)


#static func reset_all_state_to_confirmed_tick(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	#for prop_id: int in prop_ids:
		#var prop = WyncUtils.get_prop(ctx, prop_id)
		#if prop == null:
			#continue 
		#prop = prop as WyncEntityProp
		
		#var last_confirmed = prop.confirmed_states.get_at(tick)
		#if last_confirmed == null:
			#continue
		
		#prop.setter.call(last_confirmed.data)


static func reset_all_state_to_confirmed_tick_relative(ctx: WyncCtx, prop_ids: Array[int], tick: int):
	
	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			continue 
		prop = prop as WyncEntityProp
		
		
		var last_confirmed_tick = prop.last_ticks_received.get_relative(tick)
		if last_confirmed_tick == null:
			continue
		var last_confirmed = prop.confirmed_states.get_at(last_confirmed_tick as int)
		if last_confirmed == null:
			continue
		
		# TODO: check type before applying (shouldn't be necessary if we ensure we're filling the correct data)
		# Log.out(ctx, "LatestValue | setted prop_name_id %s" % [prop.name_id])
		prop.setter.call(last_confirmed)


# should be run on client each logic frame
# applies delta events and keeps delta props healthy

static func delta_props_update_and_apply_delta_events(ctx: WyncCtx, prop_ids: Array[int]):

	var delta_props_last_tick = ctx.client_has_relative_prop_has_last_tick[ctx.my_peer_id] as Dictionary

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			Log.err("SyWyncLatestValue | delta sync | couldn't find prop id(%s)" % [prop_id], Log.TAG_LATEST_VALUE)
			continue 
		prop = prop as WyncEntityProp

		var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.err("SyWyncLatestValue | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id], Log.TAG_LATEST_VALUE)
			continue
		aux_prop = aux_prop as WyncEntityProp
		
		# NOTE: Are we sure we have delta_props_last_tick[prop_id]?
		if not delta_props_last_tick.has(prop_id) || delta_props_last_tick[prop_id] == -1:
			continue

		var applied_events_until = -1

		# Fixed now? FIXME: There will be UB if between the range before last_tick_received we didn't receive an input
		# resulting in usage of old values
		# apply events in order

		for tick: int in range(delta_props_last_tick[prop_id] +1, ctx.last_tick_received +1):
			var delta_event_list = aux_prop.confirmed_states.get_at(tick)
			if delta_event_list is not Array[int]:
				Log.errc(ctx, "SyWyncLatestValue | delta sync | we don't have an input for this tick %s" % [tick], Log.TAG_LATEST_VALUE)
				break

			# before applying any events:
			# first confirm we have the event data for all events on tick

			var has_all_event_data = true
			var events_we_dont_have := []

			for event_id: int in delta_event_list:
				if WyncDeltaSyncUtils.event_is_healthy(ctx, event_id) != OK:
					has_all_event_data = false
					events_we_dont_have.append(event_id)
					#break

			if not has_all_event_data:
				Log.errc(ctx, "Some delta event data is missing from this tick (%s), we don't have %s" % [tick, events_we_dont_have])
				#if prop_id == 15:
				#	assert(false)
				break

			for event_id: int in delta_event_list:
				var err = WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

				# this error is almost fatal, should never happen, it could fail because of not finding the event
				# in that case we're gonna continue in hopes we eventually get the event data
				# TODO: implement measures against this ever happening
				if err:
					Log.err("delta sync | VERY BAD, couldn't apply event id(%s) err(%s)" % [event_id, err], Log.TAG_LATEST_VALUE)
					assert(false)
					break
				Log.out("delta sync | client consumed delta event %d" % [event_id], Log.TAG_LATEST_VALUE)

			# commit

			applied_events_until = tick
			delta_props_last_tick[prop_id] = applied_events_until


static func predicted_delta_props_rollback_to_canonic_state \
	(ctx: WyncCtx, prop_ids: Array[int], co_ticks: CoTicks, co_predict_data: CoPredictionData):

	for prop_id: int in prop_ids:
		var prop = WyncUtils.get_prop(ctx, prop_id)
		if prop == null:
			Log.err("SyWyncLatestValue | delta sync | couldn't find prop id(%s)" % [prop_id], Log.TAG_LATEST_VALUE)
			continue 
		prop = prop as WyncEntityProp

		# not checking if props are valid for this operation or not
		# that should be checked before passing prop_ids to this function

		var aux_prop = WyncUtils.get_prop(ctx, prop.auxiliar_delta_events_prop_id)
		if aux_prop == null:
			Log.err("SyWyncLatestValue | delta sync | couldn't find aux_prop id(%s)" % [prop.auxiliar_delta_events_prop_id], Log.TAG_LATEST_VALUE)
			continue
		aux_prop = aux_prop as WyncEntityProp

		Log.out("SyWyncLatestValue | server_ticks(%s) target_pred_tick(%s) last_tick_pred(%s)" % [
			co_ticks.server_ticks,
			co_predict_data.target_tick,
			ctx.last_tick_predicted
		], Log.TAG_LATEST_VALUE)

		# apply events in order

		for tick: int in range(ctx.last_tick_predicted, ctx.first_tick_predicted -1, -1):

			var undo_event_id_list = aux_prop.confirmed_states_undo.get_at(tick)
			if undo_event_id_list == null || undo_event_id_list is not Array[int]:
				assert(false)
				break
					
			undo_event_id_list = undo_event_id_list as Array[int]

			# merge state

			for event_id: int in undo_event_id_list:
				WyncDeltaSyncUtils.merge_event_to_state_real_state(ctx, prop_id, event_id)

				if not ctx.events.has(event_id):
					assert(false)
					continue
				var event_data = (ctx.events[event_id] as WyncEvent).data
				Log.out("debug_pred_delta_event | applied undo_events predicted_tick(%s) %s %s" % [tick, undo_event_id_list, HashUtils.object_to_dictionary(event_data)])


static func integrate_state(ctx: WyncCtx, wync_entity_ids: Array):
	
	# iterate all entities
	# check if they have a prop that was affected?
	# run entity integration function

	for entity_id: int in wync_entity_ids:
		
		if not ctx.entity_has_props.has(entity_id):
			continue
				
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, entity_id)
		if int_fun is Callable:
			int_fun.call()
