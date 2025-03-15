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
	wync_reset_props_to_latest_value (single_wync.ctx)
	
	
static func wync_reset_props_to_latest_value (ctx: WyncCtx):
	# Reset all extrapolated entities to last confirmed tick
	# Don't affect predicted entities?
	# TODO: store props in HashMap instead of Array
	# TODO: when receiving new state store the prop_id in a set,
	# Also, don't include extrapolated props, since they're always set anyway
	
	ctx.type_state__newstate_regular_prop_ids.clear()
	for prop_id: int in ctx.active_prop_ids:
		var prop := WyncUtils.get_prop_unsafe(ctx, prop_id)
		if prop.prop_type == WyncEntityProp.PROP_TYPE.STATE:
			if not prop.relative_syncable:
				if prop.just_received_new_state:
					prop.just_received_new_state = false
					ctx.type_state__newstate_regular_prop_ids.append(prop_id)
		
	# rest state to _canonic_

	WyncWrapper.reset_all_state_to_confirmed_tick_relative(ctx, ctx.type_state__newstate_regular_prop_ids, 0)
	
	# Note: might need to reenable this when doing _delta prop prediction_
	#WyncWrapper.reset_all_state_to_confirmed_tick_relative(ctx, ctx.type_state__predicted_regular_prop_ids, 0)

	predicted_delta_props_rollback_to_canonic_state \
			(ctx, ctx.type_state__predicted_delta_prop_ids)

	# --------------------------------------------------------------------------------

	# apply newly received delta events to catch up to _canonic_
	
	delta_props_update_and_apply_delta_events(ctx, ctx.type_state__delta_prop_ids)
	
	# call integration function to sync new transforms with physics server

	integrate_state(ctx)


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
			if aux_prop.confirmed_states_tick.get_at(tick) != tick:
				Log.errc(ctx, "SyWyncLatestValue | delta sync | we don't have an input for this tick %s" % [tick], Log.TAG_LATEST_VALUE)
				break
				
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


static func predicted_delta_props_rollback_to_canonic_state (ctx: WyncCtx, prop_ids: Array[int]):

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

		#Log.out("SyWyncLatestValue | server_ticks(%s) target_pred_tick(%s) last_tick_pred(%s)" % [
			#co_ticks.server_ticks,
			#co_predict_data.target_tick,
			#ctx.last_tick_predicted
		#], Log.TAG_LATEST_VALUE)

		# apply events in order

		for tick: int in range(ctx.last_tick_predicted, ctx.first_tick_predicted -1, -1):

			if aux_prop.confirmed_states_undo_tick.get_at(tick) != tick:
				# FIXME: this assertion was hit, but I couldn't repro it
				assert(false)
				break
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


# TODO: Move to wrapper

static func integrate_state(ctx: WyncCtx):
	
	# iterate all entities
	# check if they have a prop that was affected?
	# run entity integration function

	for entity_id: int in ctx.entity_has_integrate_fun.keys():
				
		var int_fun = WyncUtils.entity_get_integrate_fun(ctx, entity_id)
		if int_fun is Callable:
			int_fun.call()
